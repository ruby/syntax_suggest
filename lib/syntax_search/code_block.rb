# frozen_string_literal: true

module SyntaxErrorSearch
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
    attr_reader :lines

    def initialize(lines: [])
      @lines = Array(lines)
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

    def starts_at
      @starts_at ||= @lines.first&.line_number
    end

    def ends_at
      @ends_at ||= @lines.last&.line_number
    end

    # This is used for frontier ordering, we are searching from
    # the largest indentation to the smallest. This allows us to
    # populate an array with multiple code blocks then call `sort!`
    # on it without having to specify the sorting criteria
    def <=>(other)
      self.current_indent <=> other.current_indent
    end

    def current_indent
      @current_indent ||= lines.select(&:not_empty?).map(&:indent).min || 0
    end

    def invalid?
      !valid?
    end

    def valid?
      SyntaxErrorSearch.valid?(self.to_s)
    end

    def to_s
      @lines.join
    end
  end
end
