# frozen_string_literal: true

require_relative "banner"
require_relative "capture_code_context"
require_relative "display_code_with_line_numbers"

module DeadEnd
  # Used for formatting invalid blocks
  class DisplayInvalidBlocks
    attr_reader :filename

    def initialize(code_lines:, blocks:, io: $stderr, filename: nil, terminal: DEFAULT_VALUE, invalid_obj: WhoDisSyntaxError::Null.new)
      @terminal = terminal == DEFAULT_VALUE ? io.isatty : terminal

      @filename = filename
      @io = io

      @blocks = Array(blocks)

      @invalid_lines = @blocks.map(&:lines).flatten
      @code_lines = code_lines

      @invalid_obj = invalid_obj
    end

    def document_ok?
      @blocks.none? { |b| !b.hidden? }
    end

    def call
      @io.puts "Syntax OK" and return if document_ok?

      @io.puts
      if banner
        @io.puts banner
        @io.puts
      end
      @io.puts("file: #{filename}") if filename
      @io.puts <<~EOM
        simplified:

        #{indent(code_block)}
      EOM
      self
    end

    private def banner
      Banner.new(invalid_obj: @invalid_obj).call
    end

    private def indent(string, with: "    ")
      string.each_line.map { |l| with + l }.join
    end

    private def code_block
      string = +""
      string << code_with_context
      string
    end

    private def code_with_context
      lines = CaptureCodeContext.new(
        blocks: @blocks,
        code_lines: @code_lines
      ).call

      DisplayCodeWithLineNumbers.new(
        lines: lines,
        terminal: @terminal,
        highlight_lines: @invalid_lines
      ).call
    end
  end
end
