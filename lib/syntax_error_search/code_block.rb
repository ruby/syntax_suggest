# frozen_string_literal: true

module SyntaxErrorSearch
  # Multiple lines form a singular CodeBlock
  #
  # Source code is made of multiple CodeBlocks. A code block
  # has a reference to the source code that created itself, this allows
  # a code block to "expand" when needed
  #
  # The most important ability of a CodeBlock is this ability to expand:
  #
  # Example:
  #
  #   code_block.to_s # =>
  #     #   def foo
  #     #     puts "foo"
  #     #   end
  #
  #   code_block.expand_until_next_boundry
  #
  #   code_block.to_s # =>
  #     # class Foo
  #     #   def foo
  #     #     puts "foo"
  #     #   end
  #     # end
  #
  class CodeBlock
    attr_reader :lines

    def initialize(code_lines:, lines: [])
      @lines = Array(lines)
      @code_lines = code_lines
    end

    def is_end?
      to_s.strip == "end"
    end

    def starts_at
      @lines.first&.line_number
    end

    def code_lines
      @code_lines
    end

    # This is used for frontier ordering, we are searching from
    # the largest indentation to the smallest. This allows us to
    # populate an array with multiple code blocks then call `sort!`
    # on it without having to specify the sorting criteria
    def <=>(other)
      self.current_indent <=> other.current_indent
    end

    # Only the lines that are not empty and visible
    def visible_lines
      @lines
        .select(&:not_empty?)
        .select(&:visible?)
    end

    # This method is used to expand a code block to capture it's calling context
    def expand_until_next_boundry
      expand_to_indent(next_indent)
      self
    end

    # This method expands the given code block until it captures
    # its nearest neighbors. This is used to expand a single line of code
    # to its smallest likely block.
    #
    #   code_block.to_s # =>
    #     #     puts "foo"
    #   code_block.expand_until_neighbors
    #
    #   code_block.to_s # =>
    #     #     puts "foo"
    #     #     puts "bar"
    #     #     puts "baz"
    #
    def expand_until_neighbors
      expand_to_indent(current_indent)

      expand_hidden_parner_line if self.to_s.strip == "end"
      self
    end

    def expand_hidden_parner_line
      index = @lines.first.index
      indent = current_indent
      partner_line  = code_lines.select {|line| line.index < index && line.indent == indent }.last

      if partner_line&.hidden?
        partner_line.mark_visible
        @lines.prepend(partner_line)
      end
    end

    # This method expands the existing code block up (before)
    # and down (after). It will break on change in indentation
    # and empty lines.
    #
    #   code_block.to_s # =>
    #     #   def foo
    #     #     puts "foo"
    #     #   end
    #
    #   code_block.expand_to_indent(0)
    #   code_block.to_s # =>
    #     # class Foo
    #     #   def foo
    #     #     puts "foo"
    #     #   end
    #     # end
    #
    private def expand_to_indent(indent)
      array = []
      before_lines(skip_empty: false).each do |line|
        if line.empty?
          array.prepend(line)
          break
        end

        if line.indent == indent
          array.prepend(line)
        else
          break
        end
      end

      array << @lines

      after_lines(skip_empty: false).each do |line|
        if line.empty?
          array << line
          break
        end

        if line.indent == indent
          array << line
        else
          break
        end
      end

      @lines = array.flatten
    end

    def next_indent
      [
        before_line&.indent || 0,
        after_line&.indent || 0
      ].max
    end

    def current_indent
      lines.detect(&:not_empty?)&.indent || 0
    end

    def before_line
      before_lines.first
    end

    def after_line
      after_lines.first
    end

    def before_lines(skip_empty: true)
      index = @lines.first.index
      lines = code_lines.select {|line| line.index < index }
      lines.select!(&:not_empty?) if skip_empty
      lines.select!(&:visible?)
      lines.reverse!

      lines
    end

    def after_lines(skip_empty: true)
      index = @lines.last.index
      lines = code_lines.select {|line| line.index > index }
      lines.select!(&:not_empty?) if skip_empty
      lines.select!(&:visible?)
      lines
    end

    # Returns a code block of the source that does not include
    # the current lines. This is useful for checking if a source
    # with the given lines removed parses successfully. If so
    #
    # Then it's proof that the current block is invalid
    def block_without
      @block_without ||= CodeBlock.new(
        source: @source,
        lines: @source.code_lines - @lines
      )
    end

    def document_valid_without?
      block_without.valid?
    end

    def valid?
      SyntaxErrorSearch.valid?(self.to_s)
    end

    def to_s
      @lines.join
    end
  end
end
