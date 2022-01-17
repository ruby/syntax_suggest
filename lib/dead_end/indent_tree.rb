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
      # loop do
      #   requeue
      #   if document.queue.length >= @last_length
      #     break
      #   else
      #     @last_length = document.queue.length
      #     reduce
      #   end
      # end

      self
    end


    def reduce
      while block = document.pop
        original = block
        blocks = [block]

        indent = original.next_indent
        while (above = blocks.last.above) && above.indent >= indent
          blocks << above
          break if above.leaning == :left
        end

        blocks.reverse!

        while (below = blocks.last.below) && below.indent >= indent
          blocks << below
          break if below.leaning == :right
        end

        blocks.delete(original)
        if !blocks.empty?
          node = document.capture(node: original, captured: blocks)
          document.queue << node
        end
      end
      self
    end

    def requeue
      document.each do |block|
        document.queue << block
      end
    end

    def to_s
      @document.to_s
    end
  end
end
