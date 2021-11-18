require_relative "version"

require "tmpdir"
require "stringio"
require "pathname"
require "ripper"
require "timeout"

module DeadEnd
  # Used to indicate a default value that cannot
  # be confused with another input.
  DEFAULT_VALUE = Object.new.freeze

  class Error < StandardError; end
  TIMEOUT_DEFAULT = ENV.fetch("DEAD_END_TIMEOUT", 1).to_i

  # DeadEnd.handle_error [Public]
  #
  # Takes a `SyntaxError`` exception, uses the
  # error message to locate the file. Then the file
  # will be analyzed to find the location of the syntax
  # error and emit that location to stderr.
  #
  # Example:
  #
  #   begin
  #     require 'bad_file'
  #   rescue => e
  #     DeadEnd.handle_error(e)
  #   end
  #
  # By default it will re-raise the exception unless
  # `re_raise: false`. The message output location
  # can be configured using the `io: $stderr` input.
  #
  # If a valid filename cannot be determined, the original
  # exception will be re-raised (even with
  # `re_raise: false`).
  def self.handle_error(e, re_raise: true, io: $stderr)
    unless e.is_a?(SyntaxError)
      io.puts("DeadEnd: Must pass a SyntaxError, got: #{e.class}")
      raise e
    end

    file = PathnameFromMessage.new(e.message, io: io).call.name
    raise e unless file

    io.sync = true

    call(
      io: io,
      source: file.read,
      filename: file
    )

    raise e if re_raise
  end

  # DeadEnd.call [Private]
  #
  # Main private interface
  def self.call(source:, filename: DEFAULT_VALUE, terminal: DEFAULT_VALUE, record_dir: nil, timeout: TIMEOUT_DEFAULT, io: $stderr)
    search = nil
    filename = nil if filename == DEFAULT_VALUE
    Timeout.timeout(timeout) do
      record_dir ||= ENV["DEBUG"] ? "tmp" : nil
      search = CodeSearch.new(source, record_dir: record_dir).call
    end

    blocks = search.invalid_blocks
    DisplayInvalidBlocks.new(
      io: io,
      blocks: blocks,
      filename: filename,
      terminal: terminal,
      code_lines: search.code_lines
    ).call
  rescue Timeout::Error => e
    io.puts "Search timed out DEAD_END_TIMEOUT=#{timeout}, run with DEBUG=1 for more info"
    io.puts e.backtrace.first(3).join($/)
  end

  # DeadEnd.record_dir [Private]
  #
  # Used to generate a unique directory to record
  # search steps for debugging
  def self.record_dir(dir)
    time = Time.now.strftime("%Y-%m-%d-%H-%M-%s-%N")
    dir = Pathname(dir)
    symlink = dir.join("last").tap { |path| path.delete if path.exist? }
    dir.join(time).tap { |path|
      path.mkpath
      FileUtils.symlink(path.basename, symlink)
    }
  end

  # DeadEnd.valid_without? [Private]
  #
  # This will tell you if the `code_lines` would be valid
  # if you removed the `without_lines`. In short it's a
  # way to detect if we've found the lines with syntax errors
  # in our document yet.
  #
  #   code_lines = [
  #     CodeLine.new(line: "def foo\n",   index: 0)
  #     CodeLine.new(line: "  def bar\n", index: 1)
  #     CodeLine.new(line: "end\n",       index: 2)
  #   ]
  #
  #   DeadEnd.valid_without?(
  #     without_lines: code_lines[1],
  #     code_lines: code_lines
  #   )                                    # => true
  #
  #   DeadEnd.valid?(code_lines) # => false
  def self.valid_without?(without_lines:, code_lines:)
    lines = code_lines - Array(without_lines).flatten

    if lines.empty?
      true
    else
      valid?(lines)
    end
  end

  # DeadEnd.invalid? [Private]
  #
  # Opposite of `DeadEnd.valid?`
  def self.invalid?(source)
    source = source.join if source.is_a?(Array)
    source = source.to_s

    Ripper.new(source).tap(&:parse).error?
  end

  # DeadEnd.valid? [Private]
  #
  # Returns truthy if a given input source is valid syntax
  #
  #   DeadEnd.valid?(<<~EOM) # => true
  #     def foo
  #     end
  #   EOM
  #
  #   DeadEnd.valid?(<<~EOM) # => false
  #     def foo
  #       def bar # Syntax error here
  #     end
  #   EOM
  #
  # You can also pass in an array of lines and they'll be
  # joined before evaluating
  #
  #   DeadEnd.valid?(
  #     [
  #       "def foo\n",
  #       "end\n"
  #     ]
  #   ) # => true
  #
  #   DeadEnd.valid?(
  #     [
  #       "def foo\n",
  #       "  def bar\n", # Syntax error here
  #       "end\n"
  #     ]
  #   ) # => false
  #
  # As an FYI the CodeLine class instances respond to `to_s`
  # so passing a CodeLine in as an object or as an array
  # will convert it to it's code representation.
  def self.valid?(source)
    !invalid?(source)
  end
end

# Integration
require_relative "cli"

# Core logic
require_relative "code_search"
require_relative "code_frontier"
require_relative "explain_syntax"
require_relative "clean_document"
require_relative "build_block_trees"

# Helpers
require_relative "lex_all"
require_relative "code_line"
require_relative "code_block"
require_relative "block_expand"
require_relative "ripper_errors"
require_relative "insertion_sort"
require_relative "around_block_scan"
require_relative "pathname_from_message"
require_relative "display_invalid_blocks"
require_relative "parse_blocks_from_indent_line"

module DeadEnd
  class CodeTreeSearch
    attr_reader :code_lines, :invalid_blocks

    def initialize(source: , record_dir: nil)
      @code_lines = CleanDocument.new(source: source).call.lines
      @invalid_blocks = []

      if record_dir
        @record = Record::Dir.new(code_lines: @code_lines)
      else
        @record = Record::Null.new
      end
    end

    def call
      trees = BuildBlockTrees.new(code_lines: code_lines, record: @record).call.trees

      partition = PartitionArraySearch.new(trees).call { |tree| DeadEnd.invalid?(tree) }
      partition.match.each do |tree|
        match_with_parent = tree.bsearch { |code| DeadEnd.invalid?(code.to_s) }
        blocks = match_with_parent.difference(code_lines: code_lines)
        blocks.select! { |block| DeadEnd.invalid?(block) }

        @invalid_blocks.concat(blocks)
      end

      self
    end

    def inspect
      "#<DeadEnd::CodeTreeSearch:0x00007>"
    end
  end

  class Record
    class Null
      def capture(name: , block: )
      end
    end

    class Dir
      def initialize(dir: DeadEnd.record_dir("tmp"), code_lines:)
        @code_lines = code_lines
        @record_dir = dir
        @count = 0
        @name_tick = Hash.new { |hash, k| hash[k] = 0 }
      end

      def capture(name: , block: )
        filename = "#{@count += 1}-#{name}-#{@name_tick[name] += 1}.txt"

        @record_dir.join(filename).open(mode: "a") do |f|
          document = DisplayCodeWithLineNumbers.new(
            lines: @code_lines.select(&:visible?),
            terminal: false,
            highlight_lines: block.lines
          ).call

          document.prepend("     Block index: #{block.index_range} lines: #{block.starts_at..block.ends_at}\n\n")

          f.write(document)
        end
      end

      def inspect
        "#<DeadEnd::Record::Dir:0x00007 @record_dir=#{@record_dir.inspect}>"
      end
    end
  end

  # Tells you what would be left if you removed one range
  # by another
  #
  # Essentially it removes the part where the initial range
  # intersects the second range. It can return zero, one
  # or two ranges
  class RangeDiff
    attr_reader :difference

    def initialize(range, by:)
      @by =by
      @range = range
      @difference = []
    end

    def call
      if @range.min < @by.min && @range.max >= @by.max
        start_at = @range.min
        end_at = @by.min - 1
        @difference << (start_at..end_at) # Inclusive range
      end

      if @range.max > @by.max && @range.min <= @by.min
        start_at = @by.max + 1
        end_at = @range.max
        @difference << (start_at..end_at) # Inclusive range
      end

      self
    end
  end

  # Stores blocks based on their indentation for a "code "tree"
  #
  # A "tree" in this case is a secton of code that can be continually
  # expanded until it terminates at the last indent or consumes the
  # whole file. Source code can contain one or more trees.
  #
  # In this profile indentation view of code there will be 2 trees:
  #
  # ```
  # \
  #  >
  # /
  # \
  #  \
  #   >
  #  /
  # /
  # ```
  #
  # Within a tree there could be multiple other shorter "trees" that
  # terminate at a higher indentation
  #
  # All blocks in a tree are assumed to be generated
  # from the same root (line with highest indentation). This means
  # that multiple blocks will have redundant lines
  #
  # It also means that the block with the largest lenght
  # for a given indentation holds all code for that indentation
  # within a given "tree".
  #
  # Once a tree is built it is "finalized" by sorting it's keys
  # and values within the tree.
  #
  # Keys are sorted in decending order.  i.e. 10 -> 0
  #
  # Blocks within that key are sorted in length order (Ascending).
  # i.e. 0 -> 10
  #
  # The highest indentation is first (and only contains ~one line)
  # while the lowest indentation is last (usually indent=0)
  # and it's largest block contains ALL the code for the entire.
  #
  # To since every block was generated from another block on the tree
  # you can find it's parent block by looking at `@tree.at_indent(indent)[index -1]`
  # or if the index is zero: `@tree.at_indent(indent -1).last`
  class BlockIndentTree
    def initialize
      @tree = Hash.new {|h, k| h[k] = []}
      @keys = nil
    end


    # Returns the highest indentation where lambda is true
    #
    # I.e. when looking for invalid code with
    # `bsearch_indent() {|code| DeadEnd.invalid?(code) }`
    #
    # It will tell us the highest invalid indentation
    def bsearch_indent(&lambda)
      keys.bsearch { |indent| lambda.call(largest_at_indent(indent)) }
    end

    # Returns the largest index in a given indentation
    # where the lambda returns false
    #
    # I.e. when looking for invalid code with
    # `bsearch_index(indent: x) {|code| DeadEnd.invalid?(code) }`
    #
    # It will tell us the first invalid block
    def bsearch_index(indent: , &lambda)
      at_indent(indent).bsearch_index { |block| lambda.call(block) }
    end

    # Performs an indentation bsearch followed by
    # an index bsearch to find the smallest block where
    # lambda returns true
    #
    # I.e. when looking for invalid code with
    # `bsearch {|code| DeadEnd.invalid?(code) }`
    #
    # It will find the smallest block of invalid code.
    #
    # Due to the organization of the tree this block
    # is larger than it needs to be and may contain
    # a lot of valid code. We know that it's parent
    # is valid so to retrieve the smallest possible
    # element we split the found block from its parent
    # to generate up to 2 possible matches
    #
    # To aid that process a BlockWithParent object
    # containing the match and it's parent are returned
    # this object knows how to split a block from it's
    # parent given a
    def bsearch(&lambda)
      indent = bsearch_indent(&lambda)
      index = bsearch_index(indent: indent, &lambda)

      block = at_indent(indent)[index]
      parent = parent(indent: indent, index: index)

      BlockWithParent.new(block, parent: parent)
    end


    class BlockWithParent
      attr_reader :block, :parent

      def initialize(block, parent: )
        @block = block
        @parent = parent
      end

      def difference(code_lines: )
        out = []
        if !parent
          out << block
        else
          diff = RangeDiff.new(block.index_range, by: parent.index_range)
          diff.call.difference.each do |range|
            out << CodeBlock.new(lines: code_lines[range])
          end
        end

        out
      end
    end

    def parent(indent: , index: )
      return at_indent(indent)[index-1] if !index.zero?

      last_indent = parent_indent(indent)
      if last_indent
        at_indent(last_indent).last
      else
        false
      end
    end

    private def parent_indent(indent)
      key_index = keys.index(indent)
      if key_index != 0
        keys[key_index - 1]
      else
        false
      end
    end

    def <<(block)
      @tree[block.indent] << block
    end

    def each_indentation(&block)
      keys.each(&block)
    end

    def keys
      raise "Must call finalize" if @keys.nil?
      @keys
    end

    def at_indent(indent)
      @tree[indent]
    end

    def largest
      @tree[@keys.last].last
    end

    def largest_at_indent(indent)
      @tree[indent].last
    end

    def to_s
      largest.to_s
    end

    def finalize
      # Largest indent first
      @keys = @tree.keys.sort.reverse

      each_indentation do |indent|
        @tree[indent].sort! {|a, b| a.length <=> b.length }
      end
    end

    # This data structure holds a huge amount of string data
    # calling inspect on it calls inspect on each of it's blocks
    # which straight up locks up Rspec.
    #
    # Inspect is manually defined to prevent that.
    #
    # We could improve the output to be more meaningful in the future
    def inspect
      "BlockIndentTree:\n #{each_indentation.map {|k| "indent #{k} => [#{@tree[k].length} block]"}.join("\n")}"
    end
  end

  # Given an array of elements and a block that returns
  # true/false this class will subdivide the array
  # until it finds individual elements
  #
  # The main reason for this subdivision is to decrease
  # runtime cost of running Ripper.parse. If we have
  # two pieces of code `codeA` and `codeB` it is faster
  # to check `Ripper.parse(codeA + codeB)` than it is
  # to check `Ripper.parse(codeA); Ripper.parse(codeB)`.
  #
  # If we know a syntax error exists in `codeA + codeB`
  # then we can continue recursion to check each individually.
  #
  # If the combined check fails, we can eliminate checks
  #
  # The class is designed to be used with arbitrary blocks
  # however the logic must return true if ANY of the subset
  # of the array would return true by itself.
  #
  # Example:
  #
  #   partition = PartitionArraySearch.new(["def foo", "1 + 1"])
  #   partition.call {|array| DeadEnd.invalid?(array.join) }
  #
  #   puts partition.match
  #   # => ["def foo"]
  #
  class PartitionArraySearch
    attr_reader :match

    def initialize(array, &block)
      @frontier = []
      @match = []

      split = SplitArray.new(array)
      @frontier.push(split.first)
      @frontier.push(split.second) if split.can_split?
    end

    def call(&block)
      raise "no block given" unless block

      while array = @frontier.shift
        next if !block.call(array)

        split = SplitArray.new(array)
        if split.cannot_split?
          @match.concat(array)
        else
          @frontier.push(split.first)
          @frontier.push(split.second)
        end
      end

      self
    end
  end

  # Splits an array in halvsies
  #
  # Example:
  #
  #   split = SplitArray.new([8, 9])
  #   puts split.first # => [8]
  #   puts split.second # => [9]
  #
  class SplitArray
    attr_reader :first, :second, :original

    def initialize(array)
      @original = array
      @midpoint = (array.length / 2.0).floor

      @first = array[0..@midpoint - 1]
      @second = array[@midpoint..-1]
    end

    def can_split?
      @midpoint != 0
    end

    def cannot_split?
      !can_split?
    end
  end
end
