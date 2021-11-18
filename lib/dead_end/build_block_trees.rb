# frozen_string_literal: true

module DeadEnd
  # A "block tree" is described in the class `BlockIndentTree`
  #
  # Essentially it's a way to organize code
  # blocks that facilitates fast binary search for invalid segments.
  #
  # A source document contains one or more block trees. To convert
  # a source document (represented by an array of code lines),
  # a single block tree is created, then the process is performed
  # recursively for segments above and below the block tree.
  #
  # Once this process is done we can search to see which block
  # trees contain invalid code, and then search within the tree
  # to isolate the invalid code.
  #
  #   code_lines = CodeLine.from_source(<<~'EOM')
  #     def two
  #       1 + 1
  #     end
  #   EOM
  #
  #   build = BuildBlockTrees.new(code_lines: code_lines)
  #   build.call.trees.count # => 1
  #
  #   code_lines = CodeLine.from_source(<<~'EOM')
  #     def two
  #       1 + 1
  #     end
  #
  #     def three
  #       1 + two
  #     end
  #   EOM
  #
  #   build = BuildBlockTrees.new(code_lines: code_lines)
  #   build.call.trees.count # => 2
  class BuildBlockTrees
    attr_reader :trees

    def initialize(lines: nil, code_lines: , record: Record::Null.new)
      @record = record
      @code_lines = code_lines

      @lines = lines
      @lines ||= code_lines

      @line_count = @lines.length
      @min_line, max_line = @lines.minmax {|a, b| a.indent_index <=> b.indent_index }

      @block = CodeBlock.new(lines: max_line)
      @block_expand = BlockExpand.new(code_lines: code_lines)

      @record.capture(block: @block, name: "build_block_trees-init")
      @block_tree = BlockIndentTree.new
      @block_tree << @block

      @trees = []
    end

    def call
      expand_next # Expand at least once for the case where all lines are on indent zero

      until stop_expand?
        expand_next
      end

      @block_tree.finalize

      start_index = @block_tree.largest.start_index
      end_index = @block_tree.largest.end_index

      if start_index > 0
        before = @code_lines[(@lines.first.index)..(start_index - 1)]
        if !before.all?(&:empty?)
          before_trees = BuildBlockTrees.new(code_lines: @code_lines, lines: before, record: @record).call.trees
          @trees.concat(before_trees)
        end
      end

      @trees << @block_tree

      if end_index < (@line_count - 1)
        after = @code_lines[(end_index + 1)..(@lines.last.index)]
        if !after.all?(&:empty?)
          after_trees = BuildBlockTrees.new(code_lines: @code_lines, lines: after, record: @record).call.trees
          @trees.concat(after_trees)
        end
      end

      self
    end

    def to_s
      @trees.map(&:to_s).join
    end

    private def expand_next
      @block = @block_expand.call(@block)
      @record.capture(block: @block, name: "build_block_trees-expand")
      @block_tree << @block
    end

    private def captures_everything?
      @block.lines.length == @line_count
    end

    private def stop_expand?
       max_indent_expansion? || captures_everything?
    end

    private def max_indent_expansion?
      @block.indent == @min_line.indent
    end

    private def captures_everything?
      @block.lines.length == @line_count
    end
  end
end
