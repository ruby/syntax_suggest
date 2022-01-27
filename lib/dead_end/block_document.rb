# frozen_string_literal: true

module DeadEnd
  class BlockDocument
    attr_reader :blocks, :queue, :root
    attr_reader :blocks, :queue, :root, :code_lines

    include Enumerable

    def initialize(code_lines: )
      @code_lines = code_lines
      blocks = nil
      @queue = InsertionSortQueue.new
      @root = nil
    end

    def to_a
      map(&:itself)
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
        next if b.nil?
        queue << b
      end

      self
    end

    def capture_all(inner)
      lines = []
      indent = inner.first.indent
      lex_diff = LexPairDiff.new_empty
      inner.each do |block|
        lines.concat(block.lines)
        lex_diff.concat(block.lex_diff)
        block.delete
        indent = block.indent if block.indent < indent
      end

      while queue&.peek&.deleted?
        queue.pop
      end

      now = BlockNode.new(
        lines: lines,
        lex_diff: lex_diff,
        indent: indent
      )
      now.inner = inner

      if inner.first == @root
        @root = now
      end

      if inner.first&.above
        inner.first.above.below = now
        now.above = inner.first.above
      end

      if inner.last&.below
        inner.last.below.above = now
        now.below = inner.last.below
      end
      now
    end

    def capture(node: , captured: )
      inner = []
      inner.concat(Array(captured))
      inner << node
      inner.sort_by! {|block| block.start_index }

      capture_all(inner)
    end

    def pop
      @queue.pop
    end

    def peek
      @queue.peek
    end

    def inspect
      "#<DeadEnd::BlockDocument:0x000000010b375lol >"
    end
  end
end
