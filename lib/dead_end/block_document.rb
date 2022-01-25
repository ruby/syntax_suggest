# frozen_string_literal: true

module DeadEnd
  class BlockDocument
    attr_reader :blocks, :queue, :root

    include Enumerable

    def initialize(code_lines: )
      @code_lines = code_lines
      blocks = nil
      @queue = PriorityQueue.new
      @root = nil
    end

    def each
      node = @root
      while node
        yield node
        node = node.below
      end
    end

    def to_s
      string = String.new
      each do |block|
        string << block.to_s
      end
      string
    end

    def call
      last = nil
      blocks = @code_lines.map.with_index do |line, i|
        next if line.empty?

        node = BlockNode.new(lines: line, indent: line.indent)
        @root ||= node
        node.above = last
        last&.below = node
        last = node
        node
      end

      if last.above
        last.above.below = last
      end

      # Need all above/below set to determine correct next_indent
      blocks.each do |b|
        queue << b
      end

      self
    end

    def eat_above(node)
      return unless now = node&.eat_above

      if node.above == @root
        @root = now
      end

      node.above.delete
      node.delete

      while queue&.peek&.deleted?
        queue.pop
      end

      now
    end

    def eat_below(node)
      eat_above(node&.below)
    end

    def pop
      @queue.pop
    end

    def peek
      @queue.peek
    end
  end
end
