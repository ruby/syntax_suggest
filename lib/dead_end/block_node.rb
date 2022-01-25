# frozen_string_literal: true

module DeadEnd
  class BlockNode
    attr_accessor :above, :below, :left, :right, :inner
    attr_reader :lines, :start_index, :end_index, :lex_diff, :indent

    def initialize(lines: , indent:)
      lines = Array(lines)
      @indent = indent
      @lines = lines
      @left = nil
      @right = nil
      @inner = []

      @start_index = lines.first.index
      @end_index = lines.last.index
      set_lex_diff_from(@lines)

      @deleted = false
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
      case indent <=> other.indent
      when 1 then 1
      when -1 then -1
      when 0
        end_index <=> other.end_index
      end
    end

    def indent
      @indent ||= lines.map(&:indent).min || 0
    end

    def inspect
      "#<DeadEnd::BlockNode 0x000000010cbfelol #{@start_index}..#{@end_index} >"
    end

    private def set_lex_diff_from(lines)
      @lex_diff = LexPairDiff.new_empty
      lines.each do |line|
        @lex_diff.concat(line.lex_diff)
      end
    end

    def eat_above
      # return nil if above.nil?

      # node = BlockNode.new(lines: above.lines + lines, parents: [above, self])
      # if above.above
      #   node.above = above.above
      #   above.above.below = node
      # end

      # if below
      #   node.below = below
      #   below.above = node
      # end


      # node
    end

    def eat_below
      # return nil if below.nil?
      # below.eat_above
    end

    def without(other)
      BlockNode.new(lines: self.lines - other.lines)
    end
  end
end
