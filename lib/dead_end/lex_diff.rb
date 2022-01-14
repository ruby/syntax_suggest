
module DeadEnd

  class LexDiff
    def self.from_lex(lex: , is_kw: , is_end: )
      lr = LeftRightLexCount.new
      lex.each do |l|
        lr.count_lex(l)
      end

      pair_diff = lr.pair_diff_hash

      pair_diff["kw_end"] = 0
      pair_diff["kw_end"] += 1 if is_kw
      pair_diff["kw_end"] -= 1 if is_end

      LexDiff.new(
        curly: pair_diff["{}"],
        square: pair_diff["[]"],
        parens: pair_diff["()"],
        kw_end: pair_diff["kw_end"]
      )
    end

    BALANCED_HASH = {
      "{}" => 0,
      "[]" => 0,
      "()" => 0,
      "kw_end" => 0,
    }.freeze

    BALANCED_ARRAY = BALANCED_HASH.values

    attr_reader :curly, :square, :parens, :kw_end

    def initialize(curly: , square:, parens:, kw_end: )
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

    def leaning
      left = 0
      right = 0
      each do |v|
        case v <=> 0
        when 1
          left = 1
          return :unknown if right == 1
        when 0
        when -1
          right = 1
          return :unknown if left == 1
        end
      end

      if left == 1
        :left
      elsif right == 1
        :right
      else
        :equal
      end
    end

    def balanced?
      @curly == 0 && @square == 0 && @parens == 0 && @kw_end == 0
    end

    def concat(other)
      @curly += other.curly
      @square += other.square
      @parens += other.parens
      @kw_end += other.kw_end
      self
    end
  end


end
