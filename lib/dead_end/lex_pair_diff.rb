module DeadEnd
  # Holds a diff of lexical pairs
  #
  # Example:
  #
  #   diff = LexPairDiff.from_lex(LexAll.new("}"), is_kw: false, is_end: false)
  #   diff.curly # => 1
  #   diff.balanced? # => false
  #   diff.leaning # => :right
  #
  #   two = LexPairDiff.from_lex(LexAll.new("{"), is_kw: false, is_end: false)
  #   two.curly => -1
  #
  #   diff.concat(two)
  #   diff.curly # => 0
  #   diff.balanced? # => true
  #   diff.leaning # => :equal
  #
  # Internally a pair is stored as a single value
  # positive indicates more left elements, negative
  # indicates more right elements, and zero indicates
  # balanced pairs.
  class LexPairDiff
    # Convienece constructor
    def self.from_lex(lex:, is_kw:, is_end:)
      left_right = LeftRightLexCount.new
      lex.each do |l|
        left_right.count_lex(l)
      end

      kw_end = 0
      kw_end += 1 if is_kw
      kw_end -= 1 if is_end

      LexPairDiff.new(
        curly: left_right.curly_diff,
        square: left_right.square_diff,
        parens: left_right.parens_diff,
        kw_end: kw_end
      )
    end

    def self.new_empty
      self.new(curly: 0, square: 0, parens: 0, kw_end: 0)
    end

    attr_reader :curly, :square, :parens, :kw_end

    def initialize(curly:, square:, parens:, kw_end:)
      @curly = curly
      @square = square
      @parens = parens
      @kw_end = kw_end
    end

    def each
      yield @curly
      yield @square
      yield @parens
      yield @kw_end
    end

    # Returns :left if all there are more unmatched pairs to
    # left i.e. "{"
    # Returns :right if all there are more unmatched pairs to
    # left i.e. "}"
    #
    # If pairs are unmatched like "(]" returns `:both`
    #
    # If everything is balanced returns :equal
    def leaning
      dir = 0
      each do |v|
        case v <=> 0
        when 1
          return :both if dir == -1
          dir = 1
        when -1
          return :both if dir == 1
          dir = -1
        end
      end

      case dir
      when 1
        :left
      when 0
        :equal
      when -1
        :right
      end
    end

    # Returns true if all pairs are equal
    def balanced?
      @curly == 0 && @square == 0 && @parens == 0 && @kw_end == 0
    end

    # Mutates the existing diff with contents of another diff
    def concat(other)
      @curly += other.curly
      @square += other.square
      @parens += other.parens
      @kw_end += other.kw_end
      self
    end
  end
end
