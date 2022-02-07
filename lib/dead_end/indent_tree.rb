# frozen_string_literal: true

require_relative "block_recorder"

module DeadEnd

  # Each journey represents a walk of the graph to eliminate
  # invalid code
  #
  # We can check the a step's validity by asserting that it's removal produces
  # valid code from it's parent
  class Journey
    attr_reader :steps

    def initialize(root)
      @root = root
      @steps = [Step.new(root)]
    end

    def deep_dup
      j = Journey.new(@root)
      steps.each do |step|
        j << step
      end
      j
    end

    def to_s
      node.to_s
    end

    def <<(step)
      @steps << step
    end

    def node
      @steps.last.block
    end
  end

  class Step
    attr_reader :block

    def initialize(block)
      @block = block
    end

    def to_s
      block.to_s
    end
  end

  class IndentTree
    attr_reader :document, :code_lines

    def initialize(document:, record_dir: DEFAULT_VALUE)
      @document = document
      @code_lines = document.code_lines
      @last_length = Float::INFINITY


      @recorder = BlockRecorder.from_dir(record_dir, subdir: "build_tree", code_lines: @code_lines)
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
      while (block = document.pop)
        original = block
        blocks = [block]

        indent = original.next_indent

        while blocks.last.expand_above?(with_indent: indent)
          above = blocks.last.above
          leaning = above.leaning
          # break if leaning == :right
          blocks << above
          break if leaning == :left
        end

        blocks.reverse!

        while blocks.last.expand_below?(with_indent: indent)
          below = blocks.last.below
          leaning = below.leaning
          # break if leaning == :left
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
