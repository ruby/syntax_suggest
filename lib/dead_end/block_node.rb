# frozen_string_literal: true

module DeadEnd
  class BlockNode
    def self.from_blocks(parents)
      lines = []
      parents = parents.first.parents if parents.length == 1 && parents.first.parents.any?
      indent = parents.first.indent
      lex_diff = LexPairDiff.new_empty
      parents.each do |block|
        lines.concat(block.lines)
        lex_diff.concat(block.lex_diff)
        indent = block.indent if block.indent < indent
        block.delete
      end

      node = BlockNode.new(
        lines: lines,
        lex_diff: lex_diff,
        indent: indent,
        parents: parents
      )

      node.above = parents.first.above
      node.below = parents.last.below
      node
    end

    attr_accessor :above, :below, :left, :right, :parents
    attr_reader :lines, :start_index, :end_index, :lex_diff, :indent, :starts_at, :ends_at

    def initialize(lines:, indent:, next_indent: nil, lex_diff: nil, parents: [])
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

    def expand_above?(with_indent: indent)
      return false if above.nil?
      return false if leaf? && leaning == :left

      if above.leaning == :left
        above.indent >= with_indent
      else
        true
      end
    end

    def expand_below?(with_indent: indent)
      return false if below.nil?
      return false if leaf? && leaning == :right

      if below.leaning == :right
        below.indent >= with_indent
      else
        true
      end
    end

    def leaf?
      parents.empty?
    end

    def next_invalid
      parents.detect(&:invalid?)
    end

    def diagnose
      return :self if leaf?

      invalid = parents.select(&:invalid?)
      return :next_invalid if invalid.count == 1

      return :split_leaning if split_leaning?

      :multiple
    end

    # Muliple could be:
    #
    # - valid rescue/else
    # - leaves inside of an array/hash
    # - An actual fork indicating multiple syntax errors
    def handle_multiple
      invalid = parents.select(&:invalid?)
      # valid rescue/else
      if above && above.leaning == :left && below && below.leaning == :right
        before_length = invalid.length
        invalid.reject! { |block|
          b = BlockNode.from_blocks([above, block, below])
          b.leaning == :equal && b.valid?
        }
        return BlockNode.from_blocks(invalid) if invalid.any? && invalid.length != before_length
      end
    end

    def split_leaning
      block = left_right_parents
      invalid = parents.select(&:invalid?)

      invalid.reject! { |x| block.parents.include?(x) }

      @inner_leaning ||= BlockNode.from_blocks(invalid)
    end

    def left_right_parents
      invalid = parents.select(&:invalid?)
      return false if invalid.length < 3

      left = invalid.detect { |block| block.leaning == :left }

      return false if left.nil?

      right = invalid.reverse_each.detect { |block| block.leaning == :right }
      return false if right.nil?

      @left_right_parents ||= BlockNode.from_blocks([left, right])
    end

    # When a kw/end has an invalid block inbetween it will show up as [false, false, false]
    # we can check if the first and last can be joined together for a valid block which
    # effectively gives us [true, false, true]
    def split_leaning?
      block = left_right_parents
      if block
        block.leaning == :equal && block.valid?
      else
        false
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

    def invalid?
      !valid?
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
          # if leaning != other.leaning
          #   return -1 if self.leaning == :equal
          #   return 1 if other.leaning == :equal
          # end

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
