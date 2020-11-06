module SyntaxErrorSearch
  # Searches code for a syntax error
  #
  # The bulk of the heavy lifting is done by the CodeFrontier
  #
  # The flow looks like this:
  #
  # ## Syntax error detection
  #
  # When the frontier holds the syntax error, we can stop searching
  #
  #
  #   search = CodeSearch.new(<<~EOM)
  #     def dog
  #       def lol
  #     end
  #   EOM
  #
  #   search.call
  #
  #   search.invalid_blocks.map(&:to_s) # =>
  #   # => ["def lol\n"]
  #
  #
  class CodeSearch
    private; attr_reader :frontier; public
    public; attr_reader :invalid_blocks

    def initialize(string)
      @code_lines = string.lines.map.with_index do |line, i|
        CodeLine.new(line: line, index: i)
      end
      @frontier = CodeFrontier.new(code_lines: @code_lines)
      @invalid_blocks = []
    end

    def call
      until frontier.holds_all_syntax_errors?
        block = frontier.pop

        if block.valid?
          block.lines.each(&:mark_invisible)
        else
          block.expand_until_neighbors
          frontier << block
        end
      end

      @invalid_blocks.concat(frontier.detect_invalid_blocks )
      @invalid_blocks.sort_by! {|block| block.starts_at }
      self
    end
  end
end
