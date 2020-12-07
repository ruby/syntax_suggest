# frozen_string_literal: true

require_relative "capture_code_context"
require_relative "display_code_with_line_numbers"

module SyntaxErrorSearch
  # Used for formatting invalid blocks
  class DisplayInvalidBlocks
    attr_reader :filename

    def initialize(code_lines: ,blocks:, io: $stderr, filename: nil, terminal: false, invalid_type: :unmatched_end)
      @terminal = terminal
      @filename = filename
      @io = io

      @blocks = Array(blocks)

      @invalid_lines = @blocks.map(&:lines).flatten
      @code_lines = code_lines

      @invalid_type = invalid_type
    end

    def call
      if @blocks.any? { |b| !b.hidden? }
        found_invalid_blocks
      else
        @io.puts "Syntax OK"
      end
      self
    end

    private def no_invalid_blocks
      @io.puts <<~EOM
      EOM
    end

    private def found_invalid_blocks
      case @invalid_type
      when :missing_end
        @io.puts <<~EOM

          SyntaxSearch: Missing `end` detected

          This code has a missing `end`. Ensure that all
          syntax keywords (`def`, `do`, etc.) have a matching `end`.

        EOM
      when :unmatched_end
        @io.puts <<~EOM

          SyntaxSearch: Unmatched `end` detected

          This code has an unmatched `end`. Ensure that all `end` lines
          in your code have a matching syntax keyword  (`def`,  `do`, etc.)
          and that you don't have any extra `end` lines.

        EOM
      end

      @io.puts("file: #{filename}") if filename
      @io.puts <<~EOM
        simplified:

        #{indent(code_block)}
      EOM
    end

    def indent(string, with: "    ")
      string.each_line.map {|l| with  + l }.join
    end

    def code_block
      string = String.new("")
      string << code_with_context
      string
    end

    def code_with_context
      lines = CaptureCodeContext.new(
        blocks: @blocks,
        code_lines: @code_lines
      ).call

      DisplayCodeWithLineNumbers.new(
        lines: lines,
        terminal: @terminal,
        highlight_lines: @invalid_lines,
      ).call
    end

    def code_with_lines
      DisplayCodeWithLineNumbers.new(
        lines: @code_lines.select(&:visible?),
        terminal: @terminal,
        highlight_lines: @invalid_lines,
      ).call
    end
  end
end
