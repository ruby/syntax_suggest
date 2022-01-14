
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
      left = 0
      right = 0
      @diff.each do |v|
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
      @diff[0] == 0 && @diff[1] == 0 && @diff[2] == 0 && @diff[3] == 0
    end

    def to_a
      @diff
    end

    def concat(other)
      other = other.to_a
      @diff[0] += other[0]
      @diff[1] += other[1]
      @diff[2] += other[2]
      @diff[3] += other[3]
      self
    end
  end
end
