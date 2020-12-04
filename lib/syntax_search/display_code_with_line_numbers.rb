# frozen_string_literal: true

module SyntaxErrorSearch
  # Outputs code with highlighted lines
  #
  # Whatever is passed to this class will be rendered
  # even if it is "marked invisible" any filtering of
  # output should be done before calling this class.
  #
  #
  #   DisplayCodeWithLineNumbers.new(
  #     lines: lines,
  #     highlight_lines: [lines[2], lines[3]]
  #   ).call
  #   # =>
  #       1
  #       2  def cat
  #     ❯ 3    Dir.chdir
  #     ❯ 4    end
  #       5  end
  #       6
  class DisplayCodeWithLineNumbers
    TERMINAL_HIGHLIGHT = "\e[1;3m" # Bold, italics
    TERMINAL_END = "\e[0m"

    def initialize(lines: , highlight_lines: [], terminal: false)
      @lines = lines.sort
      @terminal = terminal
      @highlight_line_hash = highlight_lines.each_with_object({}) {|line, h| h[line] = true  }
      @digit_count = @lines.last&.line_number.to_s.length
    end

    def call
      @lines.map do |line|
        string = String.new("")
        if @highlight_line_hash[line]
          string << "❯ "
        else
          string << "  "
        end

        number = line.line_number.to_s.rjust(@digit_count)
        string << number.to_s
        if line.empty?
          string << line.original_line
        else
          string << "  "
          string << TERMINAL_HIGHLIGHT if @terminal && @highlight_line_hash[line] # Bold, italics
          string << line.original_line
          string << TERMINAL_END if @terminal
        end
        string
      end.join
    end
  end
end
