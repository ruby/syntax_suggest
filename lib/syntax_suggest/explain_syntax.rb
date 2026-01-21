# frozen_string_literal: true

require_relative "left_right_lex_count"

if !SyntaxSuggest.use_prism_parser?
  require_relative "ripper_errors"
end

module SyntaxSuggest
  class GetParseErrors
    def self.errors(source)
      if SyntaxSuggest.use_prism_parser?
        Prism.parse(source).errors.map(&:message)
      else
        RipperErrors.new(source).call.errors
      end
    end
  end

  # Explains syntax errors based on their source
  #
  # example:
  #
  #   source = "def foo; puts 'lol'" # Note missing end
  #   explain ExplainSyntax.new(
  #     code_lines: CodeLine.from_source(source)
  #   ).call
  #   explain.errors.first
  #   # => "Unmatched keyword, missing `end' ?"
  #
  # When the error cannot be determined by lexical counting
  # then the parser is run against the input and the raw
  # errors are returned.
  #
  # Example:
  #
  #   source = "1 * " # Note missing a second number
  #   explain ExplainSyntax.new(
  #     code_lines: CodeLine.from_source(source)
  #   ).call
  #   explain.errors.first
  #   # => "syntax error, unexpected end-of-input"
  class ExplainSyntax
    INVERSE = {
      "{" => "}",
      "}" => "{",
      "[" => "]",
      "]" => "[",
      "(" => ")",
      ")" => "(",
      "|" => "|"
    }.freeze

    def initialize(code_lines:)
      @code_lines = code_lines
      @left_right = LeftRightLexCount.new
      @missing = nil
    end

    def call
      @code_lines.each do |line|
        line.lex.each do |lex|
          @left_right.count_lex(lex)
        end
      end

      self
    end

    # Returns an array of missing elements
    #
    # For example this:
    #
    #   ExplainSyntax.new(code_lines: lines).missing
    #   # => ["}"]
    #
    # Would indicate that the source is missing
    # a `}` character in the source code
    def missing
      @missing ||= @left_right.missing
    end

    # Converts a missing string to
    # an human understandable explanation.
    #
    # Example:
    #
    #   explain.why("}")
    #   # => "Unmatched `{', missing `}' ?"
    #
    def why(miss)
      case miss
      when "keyword"
        "Unmatched `end', missing keyword (`do', `def`, `if`, etc.) ?"
      when "end"
        "Unmatched keyword, missing `end' ?"
      else
        inverse = INVERSE.fetch(miss) {
          raise "Unknown explain syntax char or key: #{miss.inspect}"
        }
        "Unmatched `#{inverse}', missing `#{miss}' ?"
      end
    end

    # Returns an array of syntax error messages
    #
    # If no missing pairs are found it falls back
    # on the original error messages
    def errors
      if missing.empty?
        return GetParseErrors.errors(@code_lines.map(&:original).join).uniq
      end

      out = missing.map { |miss| why(miss) }
      out.concat(keyword_do_block_hints)
      out
    end

    # Keywords that do not accept a `do` block
    # Note: `while` and `until` DO accept `do`, e.g. `while true do; end`
    KEYWORD_NO_DO_BLOCK = %w[if unless].freeze

    # Detects lines with a conditional keyword followed by `do`
    # (e.g., `if ... do` instead of `it ... do` (common in rspec syntax)
    #
    # Only triggers when `do` appears after `if`/`unless` but before
    # an `end` that would close it. For example:
    #
    #   `if x do; end; end` - triggers (do before if's end)
    #   `if x; end; foo do; end` - does not trigger (do after if's end)
    #
    # Returns an array of hint messages
    private def keyword_do_block_hints
      hints = []

      @code_lines.each do |line|
        # Stack of unclosed if/unless keywords
        kw_stack = []

        line.lex.each do |lex|
          next unless lex.type == :on_kw

          if lex.is_kw? && KEYWORD_NO_DO_BLOCK.include?(lex.token)
            kw_stack << lex.token
          elsif lex.token == "end" && kw_stack.any?
            # An `end` closes the most recent keyword
            kw_stack.pop
          elsif lex.token == "do" && kw_stack.any?
            # `do` appeared while there's still an unclosed if/unless
            hints << "Both `#{kw_stack.last}` and `do` require an `end`."
          end
        end
      end

      hints.uniq
    end
  end
end
