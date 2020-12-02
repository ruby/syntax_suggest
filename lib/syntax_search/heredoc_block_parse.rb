# frozen_string_literal: true

module SyntaxErrorSearch
  # Takes in a source, and returns blocks containing each heredoc
  class HeredocBlockParse
    private; attr_reader :code_lines, :lex; public

    def initialize(source:, code_lines: )
      @code_lines = code_lines
      @lex = Ripper.lex(source)
    end

    def call
      blocks = []
      beginning = []
      @lex.each do |(line, col), event, *_|
        case event
        when :on_heredoc_beg
          beginning << line
        when :on_heredoc_end
          start_index = beginning.pop - 1
          end_index = line - 1
          blocks << CodeBlock.new(lines: code_lines[start_index..end_index])
        end
      end

      blocks
    end
  end
end
