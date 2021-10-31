# frozen_string_literal: true

require_relative "capture_code_context"
require_relative "display_code_with_line_numbers"

module DeadEnd
  # Used for formatting invalid blocks
  class DisplayInvalidBlocks
    attr_reader :filename

    def initialize(code_lines:, blocks:, io: $stderr, filename: nil, terminal: DEFAULT_VALUE)
      @io = io
      @blocks = Array(blocks)
      @filename = filename
      @code_lines = code_lines

      @terminal = terminal == DEFAULT_VALUE ? io.isatty : terminal
    end

    def document_ok?
      @blocks.none? { |b| !b.hidden? }
    end

    def call
      if document_ok?
        @io.puts "Syntax OK"
        return self
      end

      @io.puts("--> #{filename}") if filename
      @io.puts
      @blocks.each do |block|
        display_block(block)
      end

      self
    end

    private def display_block(block)
      lines = CaptureCodeContext.new(
        blocks: block,
        code_lines: @code_lines
      ).call

      document = DisplayCodeWithLineNumbers.new(
        lines: lines,
        terminal: @terminal,
        highlight_lines: block.lines
      ).call

      RipperErrors.new(block.lines.map(&:original).join).call.errors.each do |e|
        @io.puts e
      end
      @io.puts

      @io.puts(document)
    end

    private def banner
      Banner.new(invalid_obj: @invalid_obj).call
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
