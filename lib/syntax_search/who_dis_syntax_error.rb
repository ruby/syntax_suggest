# frozen_string_literal: true

module SyntaxErrorSearch
  # Determines what type of syntax error is in the source
  #
  # Example:
  #
  #   puts WhoDisSyntaxError.new("def foo;").call.error_symbol
  #   # => :missing_end
  class WhoDisSyntaxError < Ripper
    attr_reader :error, :run_once, :error_symbol

    def call
      @run_once ||= begin
        parse
        true
      end
      self
    end

    def invalid_end?
      call
      return false if !error?
      return true if error_symbol != :nope
    end

    def on_parse_error(msg)
      @error = msg
      if @error.match?(/unexpected end-of-input/)
        @error_symbol = :missing_end
      elsif @error.match?(/unexpected `end'/) || @error.match?(/expecting end-of-input/)
        @error_symbol = :unmatched_end
      else
        @error_symbol = :nope
      end
    end
  end
end
