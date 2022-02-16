# frozen_string_literal: true

require_relative "block_recorder"

module DeadEnd
  # Transform a BlockDocument into a Tree
  #
  #   tree = IndentTree.new(document: document).call
  #   expect(tree.root.lines).to eq(document.code_lines)
  #
  # Nodes are put into a queue (provided by the document)
  # and are pulled out in a specific priority order (high coupling).
  #
  # A node then attempts to expand up and down according to rules here
  # and in `BlockNode#expand_above?` and `BlockNode#expand_below?`
  #
  # While this process tends to produce valid code blocks from valid code
  # it's not guaranteed. Since we will ultimately search for invalid code
  # it's not an ideal property.
  class IndentTree
    attr_reader :document, :code_lines

    def initialize(document:, record_dir: DEFAULT_VALUE)
      @document = document
      @code_lines = document.code_lines
      @last_length = Float::INFINITY

      @recorder = BlockRecorder.from_dir(record_dir, subdir: "build_tree", code_lines: @code_lines)
    end

    def peek
      document.peek
    end

    def root
      @document.root
    end

    def step
      block = document.pop
      return nil if block.nil?

      @recorder.capture(block, name: "pop")

      blocks = [block]
      indent = block.next_indent

      # Look up
      while blocks.last.expand_above?(with_indent: indent)
        above = blocks.last.above
        blocks << above

        break if above.leaning == :left
        break if above.leaning == :both && above.leaf?
      end

      blocks.reverse!

      # Look down
      while blocks.last.expand_below?(with_indent: indent)
        below = blocks.last.below
        blocks << below

        break if below.leaning == :right
        break if below.leaning == :both && below.leaf?
      end

      if blocks.length > 1
        now = document.capture_all(blocks)
        @recorder.capture(now, name: "expand")
        document.queue << now
        now
      else
        block
      end
    end

    def call
      while step
      end
      self
    end

    def to_s
      @document.to_s
    end
  end
end
