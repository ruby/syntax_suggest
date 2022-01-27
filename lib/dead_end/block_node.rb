# frozen_string_literal: true

module DeadEnd
  class BlockNode
    attr_accessor :above, :below, :left, :right, :inner
    attr_reader :lines, :start_index, :end_index, :lex_diff, :indent, :starts_at, :ends_at

    def initialize(lines: , indent: , next_indent: nil, lex_diff: nil)
      lines = Array(lines)
      @indent = indent
      @next_indent = next_indent
      @lines = lines
      @inner = []

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

    def self.next_indent(above, node, below)
      return node.indent if above && above.indent >= node.indent
      return node.indent if below && below.indent >= node.indent

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
      "#<DeadEnd::BlockNode 0x000000010cbfelol range=#{@start_index}..#{@end_index}, @indent=#{indent}, @next_indent=#{next_indent}, @inner=#{@inner.inspect}>"
    end

    private def set_lex_diff_from(lines)
      @lex_diff = LexPairDiff.new_empty
      lines.each do |line|
        @lex_diff.concat(line.lex_diff)
      end
    end

    def ==(other)
      @lines == other.lines && @indent == other.indent && next_indent == other.next_indent && @inner == other.inner
    end
  end
end
