# frozen_string_literal: true

module DeadEnd
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
    TRAILING_SLASH = ("\\" + $/).freeze

    attr_reader :line, :index, :indent, :original_line

    def initialize(line: , index:)
      @original_line = line.freeze
      @line = @original_line
      if line.strip.empty?
        @empty = true
        @indent = 0
      else
        @empty = false
        @indent = SpaceCount.indent(line)
      end
      @index = index
      @status = nil # valid, invalid, unknown
      @invalid = false

      lex_detect!
    end

    private def lex_detect!
      lex = LexAll.new(source: line)
      kw_count = 0
      end_count = 0
      lex.each do |lex|
        next unless lex.type == :on_kw

        case lex.token
        when 'def', 'case', 'for', 'begin', 'class', 'module', 'if', 'unless', 'while', 'until' , 'do'
          kw_count += 1
        when 'end'
          end_count += 1
        end
      end

      @is_comment = lex.detect {|lex| lex.type != :on_sp}&.type == :on_comment
      return if @is_comment
      @is_kw = (kw_count - end_count) > 0
      @is_end = (end_count - kw_count) > 0
      @is_trailing_slash = lex.last.token == TRAILING_SLASH
    end

    alias :original :original_line

    def trailing_slash?
      @is_trailing_slash
    end

    def indent_index
      @indent_index ||= [indent, index]
    end

    def <=>(b)
      self.index <=> b.index
    end

    def is_comment?
      @is_comment
    end

    def not_comment?
      !is_comment?
    end

    def is_kw?
      @is_kw
    end

    def is_end?
      @is_end
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
    alias :number :line_number

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
