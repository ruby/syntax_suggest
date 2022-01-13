# frozen_string_literal: true

module DeadEnd

  class LolSearch
    attr_reader :code_lines, :frontier

    def initialize(source, record_dir: DEFAULT_VALUE)
      @code_lines = CleanDocument.new(source: source).call.lines
      @frontier = CodeFrontier.new(code_lines: @code_lines)
    end

    def call
      # Prime the pumps
      balanced_blocks = []
      unvisited_balanced = UnvisitedLines.new(code_lines: code_lines.select(&:balanced?))
      while unvisited_balanced.peek
        expand = UpDownExpand.new(code_lines: code_lines, block: CodeBlock.new(lines: unvisited_balanced.pop))
        expand.call
        block = expand.to_block
        unvisited_balanced.visit_block(block)
        frontier << block
      end

      until frontier.holds_all_syntax_errors?
        block = frontier.pop
      end
    end
  end

  RSpec.describe "LOL" do
    it "flerb" do
      file = fixtures_dir.join("syntax_tree.rb.txt")
      lines = file.read.lines
      lines.delete_at(768 - 1)
      source = lines.join
      search = LolSearch.new(source)
      bench = Benchmark.measure do
        search.call
      end
    end
  end
end
