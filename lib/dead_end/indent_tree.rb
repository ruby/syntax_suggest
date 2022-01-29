# frozen_string_literal: true

module DeadEnd
  class Recorder
    def initialize(dir: , code_lines: )
      @code_lines = code_lines
      @dir = Pathname(dir)
      @tick = 0
      @name_tick = Hash.new {|h, k| h[k] = 0}
    end

    def capture(block, name: )
      @tick += 1

      filename = "#{@tick}-#{name}-#{@name_tick[name] += 1}-(#{block.starts_at}__#{block.ends_at}).txt"
      @dir.join(filename).open(mode: "a") do |f|
        document = DisplayCodeWithLineNumbers.new(
          lines: @code_lines,
          terminal: false,
          highlight_lines: block.lines
        ).call

        f.write("    Block lines: #{(block.starts_at + 1)..(block.ends_at + 1)} (#{name})\n")
        f.write("    indent: #{block.indent} next_indent: #{block.next_indent}\n\n")
        f.write("#{document}")
      end
    end
  end

  class NullRecorder
    def capture(block, name: )
    end
  end

  class IndentSearch
    def initialize(tree: )
      @tree = tree
      @invalid_blocks = []
    end


    # Keep track of trail of how we got here, Introduce Trail class
    # Each main block gets a trail with one or more paths
    #
    # Problem: We can follow valid/invalid for awhile but
    # at the edges single lines of valid code look invalid
    #
    # Solution maybe: Hold a set of code that is invalid with
    # a sub block, and valid without it. Goal: Make this block
    # as small as possible to reduce parsing time
    #
    # Problem: when to stop looking? The old "when to stop looking"
    # started from not capturing the syntax error and re-checking the
    # whole document when a syntax error was found.
    #
    # We are reversing the idea on it's head by starting with a known
    # invalid state, we know if we removed the given block the whole
    # document would be valid, however we want to find the smallest
    # block where this holds true
    #
    # Goal: Find the smallest block where it's removal will make a fork
    # of the path valid again.

    # Solution: Popstars never stop stopping
    def call
      frontier = @tree.inner.dup
      # Check outer, check inner, map parents
      while block = frontier.pop
        next if block.valid?

        if block.outer_nodes.valid?
          frontier << block.inner_nodes
        else
          # frontier << block.outer_nodes
          frontier << block.inner_nodes
        end
      end

      self
    end
  end

  class IndentTree
    attr_reader :document

    def initialize(document: , recorder: DEFAULT_VALUE)
      @document = document
      @last_length = Float::INFINITY

      if recorder != DEFAULT_VALUE
        @recorder = recorder
      else
        dir = ENV["DEAD_END_RECORD_DIR"] || ENV["DEBUG"] ? DeadEnd.record_dir("tmp") : nil
        if dir.nil?
          @recorder = NullRecorder.new
        else
          dir = dir.join("build_tree")
          dir.mkpath
          @recorder = Recorder.new(dir: dir, code_lines: document.code_lines)
        end
      end
    end

    def to_a
      @document.to_a
    end

    def root
      @document.root
    end

    def call
      reduce

      self
    end

    private def reduce
      while block = document.pop
        original = block
        blocks = [block]

        indent = original.next_indent
        while blocks.last.expand_above?(with_indent: indent)
          above = blocks.last.above
          leaning = above.leaning
          break if leaning == :right
          blocks << above
          break if leaning == :left
        end

        blocks.reverse!

        while blocks.last.expand_below?(with_indent: indent)
          below = blocks.last.below
          leaning = below.leaning
          break if leaning == :left
          blocks << below
          break if leaning == :right
        end

        @recorder.capture(original, name: "pop")

        if blocks.length > 1
          node = document.capture_all(blocks)
          @recorder.capture(node, name: "expand")
          document.queue << node
        end
      end
      self
    end

    def to_s
      @document.to_s
    end
  end
end
