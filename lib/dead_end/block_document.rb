# frozen_string_literal: true

module DeadEnd
  # Convert an array of code lines to a linked list of BlockNodes
  #
  # Each BlockNode is connected to the node above and below it.
  # A BlockNode can "capture" other nodes. This process is recursively
  # performed to build a hierarchical tree structure via IndentTree
  #
  #   document = BlockDocument.new(code_lines: code_lines)
  #   document.call
  #
  # A BlockDocument also holds a priority queue for all BlockNodes
  #
  # Empty lines are ignored so blocks in the list may have gaps in
  # line/index numbers.
  #
  # A core operation is the ability to to "capture"
  # several blocks immutably. This process creates a new block
  # that holds the captured state and substitutes it into the graph
  # data structure for the original block
  #
  #   node.above.leaning # => :left
  #   node.below.leaning # => :right

  #   block = document.capture_all([node.above, node.below])
  #   block.leaning # => :equal
  #
  class BlockDocument
    attr_reader :blocks, :queue, :root, :code_lines

    include Enumerable

    def initialize(code_lines:)
      @code_lines = code_lines
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
      string = +""
      each do |block|
        string << block.to_s
      end
      string
    end

    def call
      last = nil
      blocks = @code_lines.filter_map do |line|
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
      @queue.replace(blocks.sort)

      self
    end

    def capture_all(inner)
      now = BlockNode.from_blocks(inner)
      while queue&.peek&.deleted?
        queue.pop
      end

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

    def capture(node:, captured:)
      inner = []
      inner.concat(Array(captured))
      inner << node
      inner.sort_by! { |block| block.start_index }

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
