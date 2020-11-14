# frozen_string_literal: true

module SyntaxErrorSearch
  # Used for formatting invalid blocks
  class DisplayInvalidBlocks
    attr_reader :filename

    def initialize(code_lines: ,blocks:, io: $stderr, filename: nil, terminal: false, invalid_type: :unmatched_end)
      @terminal = terminal
      @filename = filename
      @io = io

      @blocks = Array(blocks)
      @lines = @blocks.map(&:lines).flatten
      @code_lines = code_lines
      @digit_count = @code_lines.last&.line_number.to_s.length

      @invalid_line_hash = @lines.each_with_object({}) {|line, h| h[line] = true  }
      @invalid_type = invalid_type
    end

    def call
      if @blocks.any?
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
      string << code_with_lines
      string
    end

    def terminal_end
      "\e[0m"
    end

    def terminal_highlight
      "\e[1;3m" # Bold, italics
    end

    def code_with_lines
      @code_lines.map do |line|
        next if line.hidden?

        string = String.new("")
        if @invalid_line_hash[line]
          string << "❯ "
        else
          string << "  "
        end

        number = line.line_number.to_s.rjust(@digit_count)
        string << number.to_s
        if line.empty?
          string << line.to_s
        else
          string << "  "
          string << terminal_highlight if @terminal && @invalid_line_hash[line] # Bold, italics
          string << line.to_s
          string << terminal_end if @terminal
        end
        string
      end.join
    end
  end
end
