# frozen_string_literal: true

require_relative "../spec_helper"
require "ruby-prof"

module DeadEnd
  RSpec.describe CodeTreeSearch do
    it "is fast and works" do
      file = fixtures_dir.join("syntax_tree.rb.txt")
      lines = file.read.lines
      lines.delete_at(768 - 1)

      search = CodeTreeSearch.new(source: lines.join)
      if ENV["DEBUG_PERF"]
        result = RubyProf.profile do
          search.call
        end
        dir = DeadEnd.record_dir("tmp")
        printer = RubyProf::MultiPrinter.new(result, [:flat, :graph, :graph_html, :tree, :call_tree, :stack, :dot])
        printer.print(path: dir, profile: "profile")
      else
        search.call
      end

      io = StringIO.new
      DisplayInvalidBlocks.new(
        io: io,
        blocks: search.invalid_blocks,
        terminal: false,
        code_lines: search.code_lines
      ).call

      expect(io.string).to include(<<~'EOM')
             6  class SyntaxTree < Ripper
           727    class Args
           750    end
        ❯  754    def on_args_add(arguments, argument)
           776    class ArgsAddBlock
           810    end
          9233  end
      EOM
    end
  end
end
