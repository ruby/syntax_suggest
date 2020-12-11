# frozen_string_literal: true

module DeadEnd
  # Determines what type of syntax error is in the source
  #
  # Example:
  #
  #   puts WhoDisSyntaxError.new("def foo;").call.error_symbol
  #   # => :missing_end
  class WhoDisSyntaxError < Ripper
    class Null
      def error_symbol; :missing_end; end
      def unmatched_symbol; :end ; end
      def indentation_lines; []; end
    end

    attr_reader :error, :run_once

    def warn(fmt, *args)
      @indentation_lines = []
      if fmt.match?(/mismatched indentations/)
        @indentation_lines << args.last
      end
    end

    def indentation_lines
      call
      @indentation_lines || []
    end

    def indentation_indexes
      indentation_lines.map {|x| x - 1 }
    end

    # Return options:
    #   - :missing_end
    #   - :unmatched_syntax
    #   - :unknown
    def error_symbol
      call
      @error_symbol
    end

    # Return options:
    #   - :end
    #   - :|
    #   - :}
    #   - :unknown
    def unmatched_symbol
      call
      @unmatched_symbol
    end

    def call
      @run_once ||= begin
        wrap_verbose do
          parse
        end
        true
      end
      self
    end

    # Needed to capture "weak warnings" from the parser
    # about "mismatched indentations", the same ones seen from
    # `$ ruby -wc` output.
    def wrap_verbose
      verbose = $VERBOSE
      $VERBOSE = true
      yield
    ensure
      $VERBOSE = verbose if verbose
    end

    def on_parse_error(msg)
      @error = msg
      @unmatched_symbol = :unknown

      if @error.match?(/unexpected end-of-input/)
        @error_symbol = :missing_end
      elsif @error.match?(/expecting end-of-input/)
        @error_symbol = :unmatched_syntax
        @unmatched_symbol = :end
      elsif @error.match?(/unexpected `end'/) ||  # Ruby 2.7 & 3.0
          @error.match?(/unexpected end,/) ||     # Ruby 2.6
          @error.match?(/unexpected keyword_end/) # Ruby 2.5

        @error_symbol = :unmatched_syntax

        match = @error.match(/expecting '(?<unmatched_symbol>.*)'/)
        @unmatched_symbol = match[:unmatched_symbol].to_sym if match
      else
        @error_symbol = :unknown
      end
    end
  end
end
