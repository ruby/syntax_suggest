# frozen_string_literal: true

module DeadEnd
  # Multiple lines form a singular CodeBlock
  #
  # Source code is made of multiple CodeBlocks.
  #
  # Example:
  #
  #   code_block.to_s # =>
  #     #   def foo
  #     #     puts "foo"
  #     #   end
  #
  #   code_block.valid? # => true
  #   code_block.in_valid? # => false
  #
  #
  class CodeBlock
    UNSET = Object.new.freeze
    attr_reader :lines, :starts_at, :ends_at
    attr_accessor :priority

    def initialize(lines: [])
      @lines = Array(lines)
      @valid = UNSET
      @deleted = false
      @starts_at = @lines.first.number
      @ends_at = @lines.last.number
    end

    def self.next_indent(starts_at:, ends_at:, current_indent:, code_lines:)
      before = code_lines[starts_at - 2] if starts_at > 0
      after = code_lines[ends_at]

      return current_indent if before&.hidden? || after&.hidden?
      return current_indent if before&.empty? || after&.empty?
      return current_indent if before && before.indent >= current_indent
      return current_indent if after && after.indent >= current_indent

      if before
        if after
          case before <=> after
          when 1 then after.indent
          when 0 then before.indent
          when -1 then before.indent
          end
        else
          before.indent
        end
      elsif after
        after.indent
      else # no before, no after
        current_indent
      end
    end

    def next_indent(code_lines:)
      CodeBlock.next_indent(
        starts_at: starts_at,
        ends_at: ends_at,
        current_indent: current_indent,
        code_lines: code_lines
      )
    end

    def delete
      @deleted = true
    end

    def deleted?
      @deleted
    end

    def visible_lines
      @lines.select(&:visible?).select(&:not_empty?)
    end

    def mark_invisible
      @lines.map(&:mark_invisible)
    end

    def is_end?
      to_s.strip == "end"
    end

    def hidden?
      @lines.all?(&:hidden?)
    end

    # This is used for frontier ordering, we are searching from
    # the largest indentation to the smallest. This allows us to
    # populate an array with multiple code blocks then call `sort!`
    # on it without having to specify the sorting criteria
    def <=>(other)
      out = priority <=> other.priority
      return out if out != 0

      out = current_indent <=> other.current_indent
      return out if out != 0

      starts_at <=> other.starts_at
    end

    def current_indent
      @current_indent ||= lines.select(&:not_empty?).map(&:indent).min || 0
    end

    def invalid?
      !valid?
    end

    def valid?
      if @valid == UNSET
        # Performance optimization
        #
        # If all the lines were previously hidden
        # and we expand to capture additional empty
        # lines then the result cannot be invalid
        #
        # That means there's no reason to re-check all
        # lines with ripper (which is expensive).
        # Benchmark in commit message
        @valid = if lines.all? { |l| l.hidden? || l.empty? }
          true
        else
          DeadEnd.valid?(lines.map(&:original).join)
        end
      else
        @valid
      end
    end

    def to_s
      @lines.join
    end
  end
end
