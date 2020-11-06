module SyntaxErrorSearch
  # Used for formatting invalid blocks
  class DisplayInvalidBlocks
    attr_reader :filename

    def initialize(block_array, io: $stderr, filename: nil)
      @filename = filename
      @io = io
      @blocks = block_array
      @lines = @blocks.map(&:lines).flatten
      @digit_count = @lines.last.line_number.to_s.length
      @code_lines = @blocks.first.code_lines

      @invalid_line_hash = @lines.each_with_object({}) {|line, h| h[line] = true}
    end

    def call
      @io.puts <<~EOM

        SyntaxErrorSearch: A syntax error was detected

        This code has an unmatched `end` this is caused by either
        missing a syntax keyword (`def`,  `do`, etc.) or inclusion
        of an extra `end` line

      EOM
      @io.puts("file: #{filename}") if filename
      @io.puts <<~EOM
        simplified:

        #{code_with_filename(indent: 2)}
      EOM
    end


    def code_with_filename(indent: 0)
      string = String.new("")
      string << "```\n"
      # string << "#".rjust(@digit_count) + " filename: #{filename}\n\n" if filename
      string << code_with_lines
      string << "```\n"

      string.each_line.map {|l| " " * indent + l }.join
    end

    def code_with_lines
      @code_lines.map do |line|
        next if line.hidden?
        number = line.line_number.to_s.rjust(@digit_count)
        if line.empty?
          "#{number.to_s}#{line}"
        else
          string = String.new
          string << "\e[1;3m" if @invalid_line_hash[line] # Bold, italics
          string << "#{number.to_s}  "
          string << line.to_s
          string << "\e[0m"
          string
        end
      end.join
    end
  end
end
