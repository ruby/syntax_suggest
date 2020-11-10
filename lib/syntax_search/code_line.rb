# frozen_string_literal: true

module SyntaxErrorSearch
  # Represents a single line of code of a given source file
  #
  # This object contains metadata about the line such as
  # amount of indentation. An if it is empty or not.
  #
  # While a given search for syntax errors is being performed
  # state about the search can be stored in individual lines such
  # as :valid or :invalid.
  #
  # Visibility of lines can be toggled on and off.
  #
  # Example:
  #
  #   line = CodeLine.new(line: "def foo\n", index: 0)
  #   line.line_number => 1
  #   line.empty? # => false
  #   line.visible? # => true
  #   line.mark_invisible
  #   line.visible? # => false
  #
  # A CodeBlock is made of multiple CodeLines
  #
  # Marking a line as invisible indicates that it should not be used
  # for syntax checks. It's essentially the same as commenting it out
  #
  # Marking a line as invisible also lets the overall program know
  # that it should not check that area for syntax errors.
  class CodeLine
    attr_reader :line, :index, :indent

    def initialize(line: , index:)
      @original_line = line.freeze
      @line = @original_line
      @empty = line.strip.empty?
      @index = index
      @indent = SpaceCount.indent(line)
      @status = nil # valid, invalid, unknown
      @invalid = false
    end

    def mark_invalid
      @invalid = true
      self
    end

    def marked_invalid?
      @invalid
    end

    def mark_invisible
      @line = ""
      self
    end

    def mark_visible
      @line = @original_line
      self
    end

    def visible?
      !line.empty?
    end

    def hidden?
      !visible?
    end

    def line_number
      index + 1
    end

    def not_empty?
      !empty?
    end

    def empty?
      @empty
    end

    def to_s
      self.line
    end
  end
end
