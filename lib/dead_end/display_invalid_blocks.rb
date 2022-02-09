# frozen_string_literal: true

require_relative "capture_code_context"
require_relative "display_code_with_line_numbers"

module DeadEnd
  # Used for formatting invalid blocks
  class DisplayInvalidBlocks
    attr_reader :filename, :code_lines

    def initialize(code_lines:, blocks:, io: $stderr, filename: nil, terminal: DEFAULT_VALUE, capture_mode: :old)
      @io = io
      @blocks = Array(blocks)
      @filename = filename
      @code_lines = code_lines
      @capture_mode = capture_mode

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

      if filename
        @io.puts("--> #{filename}")
        @io.puts
      end
      @blocks.each do |block|
        display_block(block)
      end

      self
    end

    private def display_block(block)
      # Build explanation
      explain = ExplainSyntax.new(
        code_lines: block.lines
      ).call

      if @capture_mode == :old
        # Enhance code output
        # Also handles several ambiguious cases
        lines = CaptureCodeContext.new(
          blocks: block,
          code_lines: @code_lines
        ).call
      else
        lines = block.lines
      end

      # Build code output
      document = DisplayCodeWithLineNumbers.new(
        lines: lines,
        terminal: @terminal,
        highlight_lines: block.lines
      ).call

      # Output syntax error explanation
      explain.errors.each do |e|
        @io.puts e
      end
      @io.puts

      # Output code
      @io.puts(document)
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
