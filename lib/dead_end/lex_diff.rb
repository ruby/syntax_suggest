
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

      array = BALANCED_ARRAY.dup
      BALANCED_HASH.each.with_index do |(k, _), i|
        array[i] = pair_diff[k]
      end

      LexDiff.new(array)
    end

    BALANCED_HASH = {
      "{}" => 0,
      "[]" => 0,
      "()" => 0,
      "kw_end" => 0,
    }.freeze

    BALANCED_ARRAY = BALANCED_HASH.values

    def initialize(array = BALANCED_ARRAY.dup)
      @diff = array
    end

    def leaning
      return :equal if balanced?
      return :left if @diff.all? {|v| v >= 0 }
      return :right if @diff.all? {|v| v <= 0 }
      return :unknown
    end

    def balanced?
      BALANCED_ARRAY == @diff
    end

    def to_a
      @diff
    end

    def concat(other)
      return self if other.balanced?

      other.to_a.each_with_index do |value, i|
        @diff[i] += value
      end
      self
    end
  end
end
