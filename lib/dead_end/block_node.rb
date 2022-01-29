# frozen_string_literal: true

module DeadEnd
  class BlockNode

    def self.from_blocks(parents)
      lines = []
      indent = parents.first.indent
      lex_diff = LexPairDiff.new_empty
      parents.each do |block|
        lines.concat(block.lines)
        lex_diff.concat(block.lex_diff)
        indent = block.indent if block.indent < indent
        block.delete
      end

      BlockNode.new(
        lines: lines,
        lex_diff: lex_diff,
        indent: indent,
        parents:parents
      )
    end

    attr_accessor :above, :below, :left, :right, :parents
    attr_reader :lines, :start_index, :end_index, :lex_diff, :indent, :starts_at, :ends_at

    def initialize(lines: , indent: , next_indent: nil, lex_diff: nil, parents: [])
      lines = Array(lines)
      @indent = indent
      @next_indent = next_indent
      @lines = lines
      @parents = parents

      @start_index = lines.first.index
      @end_index = lines.last.index

      @starts_at = @start_index + 1
      @ends_at = @end_index + 1

      if lex_diff.nil?
        set_lex_diff_from(@lines)
      else
        @lex_diff = lex_diff
      end

      @deleted = false
    end

    def split_same_indent
      output = []
      parents.each do |block|
        if block.indent == indent
          block.parents.each do |b|
            output << b
          end
        else
          output << block
        end
      end

      if output.any?
        @split_same_indent ||= BlockNode.from_blocks(output)
      else
        nil
      end
    end

    def invalid_count
      parents.select{ |block| !block.valid? }.length
    end

    def join_invalid
      invalid = parents.select{ |block| !block.valid? }

      if invalid.any?
        @join_invalid ||= BlockNode.from_blocks(invalid)
      else
        nil
      end
    end

    def outer_nodes
      outer = parents.select { |block| block.indent == indent }

      if outer.any?
        @outer_nodes ||= BlockNode.from_blocks(outer)
      else
        nil
      end
    end

    def expand_above?(with_indent: self.indent)
      return false if above.nil?

      above.indent >= with_indent
    end

    def expand_below?(with_indent: self.indent)
      return false if below.nil?

      below.indent >= with_indent
    end

    def inner_nodes
      inner = parents.select { |block| block.indent > indent }
      if inner.any?
        @inner_nodes ||= BlockNode.from_blocks(inner)
      else
        nil
      end
    end

    def self.next_indent(above, node, below)
      return node.indent if node.expand_above? || node.expand_below?

      if above
        if below
          case above.indent <=> below.indent
          when 1 then below.indent
          when 0 then above.indent
          when -1 then above.indent
          end
        else
          above.indent
        end
      elsif below
        below.indent
      else
        node.indent
      end
    end

    def next_indent
      @next_indent ||= self.class.next_indent(above, self, below)
    end

    def delete
      @deleted = true
    end

    def deleted?
      @deleted
    end

    def valid?
      return @valid if defined?(@valid)

      @valid = DeadEnd.valid?(@lines.join)
    end

    def unbalanced?
      !balanced?
    end

    def balanced?
      @lex_diff.balanced?
    end

    def leaning
      @lex_diff.leaning
    end

    def to_s
      @lines.join
    end

    def <=>(other)
      case next_indent <=> other.next_indent
      when 1 then 1
      when -1 then -1
      when 0
        case indent <=> other.indent
        when 1 then 1
        when -1 then -1
        when 0
          end_index <=> other.end_index
        end
      end
    end

    def inspect
      "#<DeadEnd::BlockNode 0x000000010cbfelol range=#{@start_index}..#{@end_index}, @indent=#{indent}, @next_indent=#{next_indent}, @parents=#{@parents.inspect}>"
    end

    private def set_lex_diff_from(lines)
      @lex_diff = LexPairDiff.new_empty
      lines.each do |line|
        @lex_diff.concat(line.lex_diff)
      end
    end

    def ==(other)
      @lines == other.lines && @indent == other.indent && next_indent == other.next_indent && @parents == other.parents
    end
  end
end
