# frozen_string_literal: true

require_relative "../spec_helper"

module DeadEnd
  RSpec.describe IndentSearch do
    it "finds random pipe (|) wildly misindented" do
      source = fixtures_dir.join("ruby_buildpack.rb.txt").read

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call
      search = IndentSearch.new(tree: tree).call

      expect(search.finished.first.node.to_s).to eq(<<~'EOM')
        |
      EOM
    end

    it "syntax tree search" do
      file = fixtures_dir.join("syntax_tree.rb.txt")
      lines = file.read.lines
      lines.delete_at(768 - 1)
      source = lines.join

      tree = nil
      document = nil
      debug_perf do
        code_lines = CleanDocument.new(source: source).call.lines
        document = BlockDocument.new(code_lines: code_lines).call
        tree = IndentTree.new(document: document).call
        search = IndentSearch.new(tree: tree).call

        expect(search.finished.first.node.to_s).to eq(<<~'EOM'.indent(2))
          def on_args_add(arguments, argument)
        EOM
      end
    end

    it "finds missing comma in array" do
      source = <<~'EOM'
        def animals
          [
            cat,
            dog
            horse
          ]
        end
      EOM

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call

      search = IndentSearch.new(tree: tree).call

      expect(search.finished.first.node.to_s).to eq(<<~'EOM'.indent(4))
        cat,
        dog
        horse
      EOM
    end
  end
end
