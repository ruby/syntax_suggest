# frozen_string_literal: true

module DeadEnd
  class IndentTree
    attr_reader :document

    def initialize(document: )
      @document = document
      @last_length = Float::INFINITY
    end

    def call
      reduce

      self
    end


    def reduce
      while block = document.pop
        original = block
        blocks = [block]

        indent = original.next_indent
        while (above = blocks.last.above) && above.indent >= indent
          break if above.leaning == :right
          blocks << above
          break if above.leaning == :left
        end

        blocks.reverse!

        while (below = blocks.last.below) && below.indent >= indent
          break if below.leaning == :left
          blocks << below
          break if below.leaning == :right
        end

        if blocks.length != 1
          node = document.capture_all(blocks)
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
