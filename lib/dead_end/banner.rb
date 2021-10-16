# frozen_string_literal: true

module DeadEnd
  class Banner
    CHARACTERS = {"}": :"{", "]": :"[", ")": :"("}
    ALL_CHARACTERS = CHARACTERS.keys + CHARACTERS.values
    attr_reader :invalid_obj

    def initialize(invalid_obj:)
      @invalid_obj = invalid_obj
    end

    def call
      case invalid_obj.error_symbol
      when :missing_end
        <<~EOM
          DeadEnd: Missing `end` detected

          This code has a missing `end`. Ensure that all
          syntax keywords (`def`, `do`, etc.) have a matching `end`.
        EOM
      when :unexpected_syntax
        case unmatched_symbol
        when *ALL_CHARACTERS
          <<~EOM
            DeadEnd: Unmatched `#{unmatched_symbol}` character detected

            It appears a `#{missing_character}` is missing.
          EOM
        else
          "DeadEnd: Unmatched `#{missing_character}` character detected"
        end
      when :unmatched_syntax
        case unmatched_symbol
        when :end
          <<~EOM
            DeadEnd: Unmatched `end` detected

            This code has an unmatched `end`. Ensure that all `end` lines
            in your code have a matching syntax keyword  (`def`,  `do`, etc.)
            and that you don't have any extra `end` lines.
          EOM
        when :|
          <<~EOM
            DeadEnd: Unmatched `|` character detected

            Example:

              `do |x` should be `do |x|`
          EOM
        when *ALL_CHARACTERS
          <<~EOM
            DeadEnd: Unmatched `#{missing_character}` character detected

            It appears a `#{unmatched_symbol}` is missing.
          EOM
        else
          "DeadEnd: Unmatched `#{missing_character}` detected"
        end
      end
    end

    private def missing_character
      CHARACTERS[unmatched_symbol] || CHARACTERS.key(unmatched_symbol) || :unknown
    end

    private def unmatched_symbol
      invalid_obj.unmatched_symbol
    end
  end
end
