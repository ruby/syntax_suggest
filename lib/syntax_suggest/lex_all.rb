# frozen_string_literal: true

module SyntaxSuggest
  # Lexes the whole source and wraps the tokens in `LexValue`.
  #
  # Example usage:
  #
  #   lex = LexAll.new(source: source)
  #   lex.each do |value|
  #     puts value.line
  #   end
  class LexAll
    include Enumerable

    def initialize(source:)
      @lex = self.class.lex(source, 1)
      last_lex = nil
      @lex.map! { |elem|
        last_lex = LexValue.new(elem[0].first, elem[1], elem[2], elem[3], last_lex)
      }
    end

    def self.lex(source, line_number)
      Prism.lex_compat(source, line: line_number).value.sort_by { |values| values[0] }
    end

    def to_a
      @lex
    end

    def each
      return @lex.each unless block_given?
      @lex.each do |x|
        yield x
      end
    end

    def [](index)
      @lex[index]
    end

    def last
      @lex.last
    end
  end
end

require_relative "lex_value"
