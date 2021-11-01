# frozen_string_literal: true

module DeadEnd
  # Capture parse errors from ripper
  #
  # Example:
  #
  #   puts RipperErrors.new(" def foo").call.errors
  #   # => ["syntax error, unexpected end-of-input, expecting ';' or '\\n'"]
  class RipperErrors < Ripper
    attr_reader :errors

    # Comes from ripper, called
    # on every parse error, msg
    # is a string
    def on_parse_error(msg)
      @errors ||= []
      @errors << msg
    end

    def call
      @run_once ||= begin
        @errors = []
        parse
        true
      end
      self
    end
  end
end
