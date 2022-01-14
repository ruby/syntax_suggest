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
      while line = unvisited_balanced.peek

        zero = CodeBlock.new(lines: unvisited_balanced.pop)
        blocks = [zero]
        expand = UpDownExpand.new(code_lines: code_lines, block: zero)
        one = expand.call.to_block
        blocks << one if expand.balanced?
        two = expand.call.to_block
        blocks << two if expand.balanced?


        block = blocks.reverse_each.detect(&:valid?)
        block ||= zero

        unvisited_balanced.visit_block(block)
        frontier << block
        if block.valid?
          block.mark_invisible
        end
      end

      # until frontier.holds_all_syntax_errors?
      #   block = frontier.pop
      # end

      # @invalid_blocks.concat(frontier.detect_invalid_blocks)
      # @invalid_blocks.sort_by! { |block| block.starts_at }
    end
  end

  RSpec.describe "LOL" do
    it "isn't so damned greedy" do
      skip
        # location: arguments.location.to(argument.location)

      source = <<~'EOM'
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
        debug_perf do
          search.call
        end
      end


      puts search.invalid_blocks.length
      puts search.invalid_blocks.join
    end
  end
end
