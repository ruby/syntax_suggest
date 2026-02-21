# frozen_string_literal: true

module SyntaxSuggest
  # Ripper.lex is not guaranteed to lex the entire source document
  #
  # This class guarantees the whole document is lex-ed by iteratively
  # lexing the document where ripper stopped.
  #
  # Prism likely doesn't have the same problem. Once ripper support is removed
  # we can likely reduce the complexity here if not remove the whole concept.
  #
  # Example usage:
  #
  #   tokens = LexAll.new(source: source)
  #   tokens.each do |token|
  #     puts token.line
  #   end
  class LexAll
    include Enumerable

    def initialize(source:, source_lines: nil)
      @tokens = self.class.lex(source, 1)
      lineno = @tokens.last[0][0] + 1
      source_lines ||= source.lines
      last_lineno = source_lines.length

      until lineno >= last_lineno
        lines = source_lines[lineno..]

        @tokens.concat(
          self.class.lex(lines.join, lineno + 1)
        )

        lineno = @tokens.last[0].first + 1
      end

      last_token = nil
      @tokens.map! { |elem|
        last_token = Token.new(elem[0].first, elem[1], elem[2], elem[3], last_token)
      }
    end

    if SyntaxSuggest.use_prism_parser?
      def self.lex(source, line_number)
        Prism.lex_compat(source, line: line_number).value.sort_by { |values| values[0] }
      end
    else
      def self.lex(source, line_number)
        Ripper::Lexer.new(source, "-", line_number).parse.sort_by(&:pos)
      end
    end

    def to_a
      @tokens
    end

    def each
      return @tokens.each unless block_given?
      @tokens.each do |token|
        yield token
      end
    end

    def [](index)
      @tokens[index]
    end

    def last
      @tokens.last
    end
  end
end

require_relative "token"
