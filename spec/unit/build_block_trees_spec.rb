# frozen_string_literal: true

require_relative "../spec_helper"
require "ruby-prof"

module DeadEnd
  class FlerbSearch
  end

  RSpec.describe BuildBlockTrees do
    it "preserves code lines for iteration" do
      code_lines = CodeLine.from_source(<<~'EOM')
        class Bar
          def lol
        end
        class Baz
        end
      EOM

      build = BuildBlockTrees.new(code_lines: code_lines)
      expect(build.call.trees.count).to eq(2)
    end

    it "builds one block trees" do
      code_lines = CodeLine.from_source(<<~'EOM')
        def two
          1 + 1
        end
      EOM

      build = BuildBlockTrees.new(code_lines: code_lines)
      expect(build.call.trees.count).to eq(1)
    end

    it "builds two block trees" do
      code_lines = CodeLine.from_source(<<~'EOM')
        def two
          1 + 1
        end

        def three
          1 + two
        end
      EOM

      build = BuildBlockTrees.new(code_lines: code_lines).call
      # expect(build.trees.count).to eq(2)
      expect(build.trees.first.to_s).to eq(<<~'EOM')
        def two
          1 + 1
        end
      EOM
      expect(build.trees.last.to_s).to eq(<<~'EOM')
        def three
          1 + two
        end
      EOM

      expect(build.to_s).to eq(code_lines.join.gsub("\n\n", "\n"))
    end

    it "groups large logical blocks in one section" do
      source = <<~'EOM'
        class Foo
          class Bar
            def lol
          end
          class Baz
          end
        end
      EOM

      build = BuildBlockTrees.new(code_lines: CodeLine.from_source(source)).call

      tree = build.trees.first
      expect(tree.largest_at_indent(2).to_s).to eq(<<~'EOM'.indent(2))
        class Bar
          def lol
        end
        class Baz
        end
      EOM
      expect(tree.at_indent(2).count).to eq(2)

      expect(tree.largest_at_indent(4).to_s).to eq(<<~'EOM'.indent(4))
        def lol
      EOM
      expect(tree.at_indent(4).count).to eq(1)
    end
  end
end
