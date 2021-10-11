module DeadEnd
  # Ripper.lex is not guaranteed to lex the entire source document
  #
  # lex = LexAll.new(source: source)
  # lex.each do |value|
  #   puts value.line
  # end
  class LexAll
    include Enumerable

    def initialize(source:)
      @lex = Ripper.lex(source)
      lineno = @lex.last.first.first + 1
      source_lines = source.lines
      last_lineno = source_lines.count

      until lineno >= last_lineno
        lines = source_lines[lineno..]

        @lex.concat(Ripper.lex(lines.join, "-", lineno + 1))
        lineno = @lex.last.first.first + 1
      end

      @lex.map! { |(line, _), type, token, state| LexValue.new(line, type, token, state) }
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
