# frozen_string_literal: true

module DeadEnd

  class LolSearch
    attr_reader :code_lines, :frontier, :invalid_blocks

    def initialize(source, record_dir: DEFAULT_VALUE)
      @code_lines = CleanDocument.new(source: source).call.lines
      @frontier = CodeFrontier.new(code_lines: @code_lines)
      @invalid_blocks = []
    end

    def call
      # Prime the pumps
      balanced_blocks = []
      unvisited_balanced = UnvisitedLines.new(code_lines: code_lines.select(&:balanced?))
      count = 0
      while line = unvisited_balanced.peek
        count += 1
        puts count

        expand = UpDownExpand.new(code_lines: code_lines, block: CodeBlock.new(lines: unvisited_balanced.pop))
        expand.call
        block = expand.to_block
        unvisited_balanced.visit_block(block)
        frontier << block
        if block.valid?
          block.mark_invisible
        end
        puts "=="
        puts line
        puts block.valid?
        puts block
        break if frontier.holds_all_syntax_errors?
      end

      # until frontier.holds_all_syntax_errors?
      #   block = frontier.pop
      # end

      @invalid_blocks.concat(frontier.detect_invalid_blocks)
      @invalid_blocks.sort_by! { |block| block.starts_at }
    end
  end

  RSpec.describe "LOL" do
    it "isn't so damned greedy" do
        # location: arguments.location.to(argument.location)

      source <<~'EOM'
        def on_args_add(arguments, argument)
          if arguments.parts.empty?



            Args.new(parts: [argument], location: argument.location)
          else


            Args.new(
              parts: arguments.parts << argument,
              location: arguments.location.to(argument.location)
            )
          end
      EOM

      raise "lol"

    end


    it "flerb" do
      file = fixtures_dir.join("syntax_tree.rb.txt")
      lines = file.read.lines
      lines.delete_at(768 - 1)
      source = lines.join
      search = LolSearch.new(source)
      bench = Benchmark.measure do
        search.call
      end


      puts search.invalid_blocks.length
      puts search.invalid_blocks.join
    end
  end
end
