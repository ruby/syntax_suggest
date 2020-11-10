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
    public; attr_reader :invalid_blocks, :record_dir, :code_lines

    def initialize(string, record_dir: ENV["SYNTAX_SEARCH_RECORD_DIR"])
      if record_dir
        @time = Time.now.strftime('%Y-%m-%d-%H-%M-%s-%N')
        @record_dir = Pathname(record_dir).join(@time).tap {|p| p.mkpath }
        @write_count = 0
      end
      @code_lines = string.lines.map.with_index do |line, i|
        CodeLine.new(line: line, index: i)
      end
      @frontier = CodeFrontier.new(code_lines: @code_lines)
      @invalid_blocks = []
      @name_tick = Hash.new {|hash, k| hash[k] = 0 }
      @tick = 0
      @scan = IndentScan.new(code_lines: @code_lines)
    end

    def record(block:, name: "record")
      return if !@record_dir
      @name_tick[name] += 1
      filename = "#{@write_count += 1}-#{name}-#{@name_tick[name]}.txt"
      @record_dir.join(filename).open(mode: "a") do |f|
        display = DisplayInvalidBlocks.new(
          blocks: block,
          terminal: false
        )
        f.write(display.indent display.code_with_lines)
      end
    end

    def push_if_invalid(block, name: )
      frontier.register(block)
      record(block: block, name: name)

      if block.valid?
        block.lines.each(&:mark_invisible)
        frontier << block
      else
        frontier << block
      end
    end

    def add_invalid_blocks
      max_indent = frontier.next_indent_line&.indent

      while (line = frontier.next_indent_line) && (line.indent == max_indent)
        neighbors = @scan.neighbors_from_top(frontier.next_indent_line)

        @scan.each_neighbor_block(frontier.next_indent_line) do |block|
          record(block: block, name: "add")
          if block.valid?
            block.lines.each(&:mark_invisible)
          end
        end

        block = CodeBlock.new(lines: neighbors, code_lines: @code_lines)
        push_if_invalid(block, name: "add")
      end
    end

    def expand_invalid_block
      block = frontier.pop
      return unless block

      block.expand_until_next_boundry
      push_if_invalid(block, name: "expand")
    end

    def call
      until frontier.holds_all_syntax_errors?
        @tick += 1

        if frontier.expand?
          expand_invalid_block
        else
          add_invalid_blocks
        end
      end

      @invalid_blocks.concat(frontier.detect_invalid_blocks )
      @invalid_blocks.sort_by! {|block| block.starts_at }
      self
    end
  end
end
