# frozen_string_literal: true

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
    public; attr_reader :invalid_blocks, :record_dir

    def initialize(string, record_dir: ENV["SYNTAX_SEARCH_RECORD_DIR"])
      if record_dir
        @time = Time.now.strftime('%Y-%m-%d-%H-%M-%s-%N')
        @record_dir = Pathname(record_dir).join(@time)
      end
      @code_lines = string.lines.map.with_index do |line, i|
        CodeLine.new(line: line, index: i)
      end
      @frontier = CodeFrontier.new(code_lines: @code_lines)
      @invalid_blocks = []
      @name_tick = Hash.new {|hash, k| hash[k] = 0 }
      @tick = 0
    end

    def record(block:, name: "record")
      return if !@record_dir
      @name_tick[name] += 1
      file = @record_dir.join("#{@tick}-#{name}-#{@name_tick[name]}.txt").tap {|p| p.dirname.mkpath }
      file.open(mode: "a") do |f|
        display = DisplayInvalidBlocks.new(
          blocks: block,
          terminal: false
        )
        f.write(display.indent display.code_with_lines)
      end
    end

    def expand_frontier
      return if !frontier.next_block?
      block = frontier.next_block
      record(block: block, name: "add")
      if block.valid?
        block.lines.each(&:mark_invisible)
        return expand_frontier
      else
        frontier << block
      end
      block
    end

    def search
      block = frontier.pop

      block.expand_until_next_boundry
      record(block: block, name: "expand")
      if block.valid?
        block.lines.each(&:mark_invisible)
      else
        frontier << block
      end
    end

    def call
      until frontier.holds_all_syntax_errors?
        @tick += 1
        expand_frontier
        break if frontier.holds_all_syntax_errors? # Need to check after every time something is added to frontier
        search
      end

      @invalid_blocks.concat(frontier.detect_invalid_blocks )
      @invalid_blocks.sort_by! {|block| block.starts_at }
      self
    end
  end
end
