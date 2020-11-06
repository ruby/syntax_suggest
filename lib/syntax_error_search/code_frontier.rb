module SyntaxErrorSearch
  # This class is responsible for generating, storing, and sorting code blocks
  #
  # The search algorithm for finding our syntax errors isn't in this class, but
  # this is class holds the bulk of the logic for generating, storing, detecting
  # and filtering invalid code.
  #
  # This is loosely based on the idea of a "frontier" for searching for a path
  # example: https://en.wikipedia.org/wiki/Dijkstra%27s_algorithm
  #
  # In this case our path is going from code with a syntax error to code without a
  # syntax error. We're currently doing that by evaluating individual lines
  # with respect to indentation and other whitespace (empty lines). As represented
  # by individual "code blocks".
  #
  # This class does not just store the frontier that we're searching, but is responsible
  # for generating new code blocks as well. This is not ideal, but the state of generating
  # and evaluating paths i.e. codeblocks is very tightly coupled.
  #
  # ## Creation
  #
  # This example code is re-used in the other sections
  #
  # Example:
  #
  #   code_lines = [
  #     CodeLine.new(line: "def cinco\n", index: 0)
  #     CodeLine.new(line: "  def dog\n", index: 1) # Syntax error 1
  #     CodeLine.new(line: "  def cat\n", index: 2) # Syntax error 2
  #     CodeLine.new(line: "end\n",       index: 3)
  #   ]
  #
  #   frontier = CodeFrontier.new(code_lines: code_lines)
  #
  #   frontier << frontier.next_block if frontier.next_block?
  #   frontier << frontier.next_block if frontier.next_block?
  #
  #   frontier.holds_all_syntax_errors? # => true
  #   block = frontier.pop
  #   frontier.holds_all_syntax_errors? # => false
  #   frontier << block
  #   frontier.holds_all_syntax_errors? # => true
  #
  #   frontier.detect_invalid_blocks.map(&:to_s) # =>
  #   [
  #     "def dog\n",
  #     "def cat\n"
  #   ]
  #
  # ## Block Generation
  #
  # Currently code blocks are generated based off of indentation. With the idea that blocks are,
  # well, indented. Once a code block is added to the frontier or it is expanded, or it is generated
  # then we also need to remove those lines from our generation code so we don't generate the same block
  # twice by accident.
  #
  # This is block generation is currently done via the "indent_hash" internally by starting at the outer
  # most indentation.
  #
  # Example:
  #
  #   ```
  #   def river
  #     puts "lol" # <=== Start looking here and expand outwards
  #   end
  #   ```
  #
  # Generating new code blocks is a little verbose but looks like this:
  #
  #   frontier << frontier.next_block if frontier.next_block?
  #
  # Once a block is in the frontier, it can be popped off:
  #
  #   frontier.pop
  #   # => <# CodeBlock >
  #
  # ## Block (frontier) storage, ordering and retrieval
  #
  # Once a block is generated it is stored internally in a frontier array. This is very similar to a search algorithm.
  # The array is sorted by indentation order, so that when a block is popped off the array, the one with
  # the largest current indentation is evaluated first.
  #
  # For example, if we have these two blocks in the frontier:
  #
  #   ```
  #   # Block A - 0 spaces for indentation
  #
  #   def cinco
  #     puts "lol"
  #   end
  #   ```
  #
  #   ```
  #   # Block B - 2 spaces for indentation
  #
  #     def river
  #       puts "hehe"
  #     end
  #   ```
  #
  # The "Block B" has more current indentation, so it would be evaluated first.
  #
  # ## Frontier evaluation (Find the syntax error)
  #
  # Another key difference between this and a normal search "frontier" is that we're not checking if
  # an individual code block meets the goal (turning invalid code to valid code) since there can
  # be multiple syntax errors and this will require multiple code blocks. To handle this, we're
  # evaluating all the contents of the frontier at the same time to see if the solution exists in any
  # of our search blocks.
  #
  #   # Using the previously generated frontier
  #
  #   frontier << Block.new(lines: code_lines[1], code_lines: code_lines)
  #   frontier.holds_all_syntax_errors? # => false
  #
  #   frontier << Block.new(lines: code_lines[2], code_lines: code_lines)
  #   frontier.holds_all_syntax_errors? # => true
  #
  # ## Detect invalid blocks (Filter for smallest solution)
  #
  # After we prove that a solution exists and we've found it to be in our frontier, we can start stop searching.
  # Once we've done this, we need to search through the existing frontier code blocks to find the minimum combination
  # of blocks that hold the solution. This is done in: `detect_invalid_blocks`.
  #
  #   # Using the previously generated frontier
  #
  #   frontier << CodeBlock.new(lines: code_lines[0], code_lines: code_lines)
  #   frontier << CodeBlock.new(lines: code_lines[1], code_lines: code_lines)
  #   frontier << CodeBlock.new(lines: code_lines[2], code_lines: code_lines)
  #   frontier << CodeBlock.new(lines: code_lines[3], code_lines: code_lines)
  #
  #   frontier.count # => 4
  #   frontier.detect_invalid_blocks.length => 2
  #   frontier.detect_invalid_blocks.map(&:to_s) # =>
  #   [
  #     "def dog\n",
  #     "def cat\n"
  #   ]
  #
  # Once invalid blocks are found and filtered, then they can be passed to a formatter.
  class CodeFrontier
    def initialize(code_lines: )
      @code_lines = code_lines
      @frontier = []
      @indent_hash = {}
      code_lines.each do |line|
        next if line.empty?

        @indent_hash[line.indent] ||= []
        @indent_hash[line.indent] << line
      end
    end

    def count
      @frontier.count
    end

    # Returns true if the document is valid with all lines
    # removed. By default it checks all blocks in present in
    # the frontier array, but can be used for arbitrary arrays
    # of codeblocks as well
    def holds_all_syntax_errors?(block_array = @frontier)
      without_lines = block_array.map do |block|
        block.lines
      end

      SyntaxErrorSearch.valid_without?(
        without_lines: without_lines,
        code_lines: @code_lines
      )
    end

    # Returns a code block with the largest indentation possible
    def pop
      return nil if empty?

      return @frontier.pop
    end

    def next_block?
      !@indent_hash.empty?
    end

    def next_block
      indent = @indent_hash.keys.sort.last
      lines = @indent_hash[indent].first

      CodeBlock.new(
        lines: lines,
        code_lines: @code_lines
      ).expand_until_neighbors
    end

    # This method is responsible for determining if a new code
    # block should be generated instead of evaluating an already
    # existing block in the frontier
    def generate_new_block?
      return false if @indent_hash.empty?
      return true if @frontier.empty?

      @frontier.last.current_indent <= @indent_hash.keys.sort.last
    end

    # Add a block to the frontier
    #
    # This method ensures the frontier always remains sorted (in indentation order)
    # and that each code block's lines are removed from the indentation hash so we
    # don't re-evaluate the same line multiple times.
    def <<(block)
      block.lines.each do |line|
        @indent_hash[line.indent]&.delete(line)
      end
      @indent_hash.select! {|k, v| !v.empty?}

      @frontier << block
      @frontier.sort!

      self
    end

    def any?
      !empty?
    end

    def empty?
      @frontier.empty? && @indent_hash.empty?
    end

    # Example:
    #
    #   combination([:a, :b, :c, :d])
    #   # => [[:a], [:b], [:c], [:d], [:a, :b], [:a, :c], [:a, :d], [:b, :c], [:b, :d], [:c, :d], [:a, :b, :c], [:a, :b, :d], [:a, :c, :d], [:b, :c, :d], [:a, :b, :c, :d]]
    def self.combination(array)
      guesses = []
      1.upto(array.length).each do |size|
        guesses.concat(array.combination(size).to_a)
      end
      guesses
    end

    # Given that we know our syntax error exists somewhere in our frontier, we want to find
    # the smallest possible set of blocks that contain all the syntax errors
    def detect_invalid_blocks
      self.class.combination(@frontier).detect do |block_array|
        holds_all_syntax_errors?(block_array)
      end || []
    end
  end
end
