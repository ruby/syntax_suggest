# frozen_string_literal: true

require_relative "../spec_helper"

module DeadEnd
  RSpec.describe CodeSearch do
    it "handles mismatched |" do
      source = <<~EOM
        class Blerg
          Foo.call do |a
          end # one

          puts lol
          class Foo
          end # two
        end # three
      EOM
      search = CodeSearch.new(source)
      search.call

      expect(search.invalid_blocks.join).to eq(<<~EOM.indent(2))
        Foo.call do |a
        end # one
      EOM
    end

    it "handles mismatched }" do
      source = <<~EOM
        class Blerg
          Foo.call do {

          puts lol
          class Foo
          end # two
        end # three
      EOM
      search = CodeSearch.new(source)
      search.call

      expect(search.invalid_blocks.join).to eq(<<~EOM.indent(2))
        Foo.call do {
      EOM
    end

    it "handles no spaces between blocks and trailing slash" do
      source = <<~'EOM'
        require "rails_helper"
        RSpec.describe Foo, type: :model do
          describe "#bar" do
            context "context" do
              it "foos the bar with a foo and then bazes the foo with a bar to"\
                "fooify the barred bar" do
                travel_to DateTime.new(2020, 10, 1, 10, 0, 0) do
                  foo = build(:foo)
                end
              end
            end
          end
          describe "#baz?" do
            context "baz has barred the foo" do
              it "returns true" do # <== HERE
            end
          end
        end
      EOM

      search = CodeSearch.new(source)
      search.call

      expect(search.invalid_blocks.join.strip).to eq('it "returns true" do # <== HERE')
    end

    it "handles no spaces between blocks" do
      source = <<~EOM
        context "foo bar" do
          it "bars the foo" do
            travel_to DateTime.new(2020, 10, 1, 10, 0, 0) do
            end
          end
        end
        context "test" do
          it "should" do
        end
      EOM
      search = CodeSearch.new(source)
      search.call

      expect(search.invalid_blocks.join.strip).to eq('it "should" do')
    end

    it "records debugging steps to a directory" do
      Dir.mktmpdir do |dir|
        dir = Pathname(dir)
        search = CodeSearch.new(<<~EOM, record_dir: dir)
          class OH
            def hello
            def hai
            end
          end
        EOM
        search.call

        expect(search.record_dir.entries.map(&:to_s)).to include("1-add-1-(3__4).txt")
        expect(search.record_dir.join("1-add-1-(3__4).txt").read).to include(<<~EOM)
            1  class OH
            2    def hello
          ❯ 3    def hai
          ❯ 4    end
            5  end
        EOM
      end
    end

    it "def with missing end" do
      search = CodeSearch.new(<<~EOM)
        class OH
          def hello

          def hai
            puts "lol"
          end
        end
      EOM
      search.call

      expect(search.invalid_blocks.join.strip).to eq("def hello")

      search = CodeSearch.new(<<~EOM)
        class OH
          def hello

          def hai
          end
        end
      EOM
      search.call

      expect(search.invalid_blocks.join.strip).to eq("def hello")

      search = CodeSearch.new(<<~EOM)
        class OH
          def hello
          def hai
          end
        end
      EOM
      search.call

      expect(search.invalid_blocks.join).to eq(<<~EOM.indent(2))
        def hello
      EOM
    end

    describe "real world cases" do
      it "finds hanging def in this project" do
        source_string = fixtures_dir.join("this_project_extra_def.rb.txt").read
        search = CodeSearch.new(source_string)
        search.call

        document = DisplayCodeWithLineNumbers.new(
          lines: search.code_lines.select(&:visible?),
          terminal: false,
          highlight_lines: search.invalid_blocks.flat_map(&:lines)
        ).call

        expect(document).to include(<<~EOM)
          ❯ 36      def filename
        EOM
      end

      it "Format Code blocks real world example" do
        search = CodeSearch.new(<<~EOM)
          require 'rails_helper'

          RSpec.describe AclassNameHere, type: :worker do
            describe "thing" do
              context "when" do
                let(:thing) { stuff }
                let(:another_thing) { moarstuff }
                subject { foo.new.perform(foo.id, true) }

                it "stuff" do
                  subject

                  expect(foo.foo.foo).to eq(true)
                end
              end
            end # line 16 accidental end, but valid block

              context "stuff" do
                let(:thing) { create(:foo, foo: stuff) }
                let(:another_thing) { create(:stuff) }

                subject { described_class.new.perform(foo.id, false) }

                it "more stuff" do
                  subject

                  expect(foo.foo.foo).to eq(false)
                end
              end
            end # mismatched due to 16
          end
        EOM
        search.call

        document = DisplayCodeWithLineNumbers.new(
          lines: search.code_lines.select(&:visible?),
          terminal: false,
          highlight_lines: search.invalid_blocks.flat_map(&:lines)
        ).call

        expect(document).to include(<<~EOM)
             1  require 'rails_helper'
             2
             3  RSpec.describe AclassNameHere, type: :worker do
          ❯  4    describe "thing" do
          ❯ 16    end # line 16 accidental end, but valid block
          ❯ 30    end # mismatched due to 16
            31  end
        EOM
      end
    end

    # For code that's not perfectly formatted, we ideally want to do our best
    # These examples represent the results that exist today, but I would like to improve upon them
    describe "needs improvement" do
      describe "missing describe/do line" do
        it "blerg" do
          # code_lines = code_line_array fixtures_dir.join("this_project_extra_def.rb.txt").read
          # block = CodeBlock.new(
          #   lines: code_lines[31],
          #   code_lines: code_lines
          # )
          # expect(block.to_s).to eq(<<~EOM.indent(8))
          #   \#{code_with_filename}
          # EOM

          # puts    block.before_line.to_s.inspect
          # puts    block.before_line.to_s.split(/\S/).inspect
          # puts    block.before_line.indent

          # puts    block.after_line.to_s.inspect
          # puts    block.after_line.to_s.split(/\S/).inspect
          # puts    block.after_line.indent

          # puts block.expand_until_next_boundry
        end
      end

      describe "mis-matched-indentation" do
        it "extra space before end" do
          search = CodeSearch.new(<<~EOM)
            Foo.call
              def foo
                puts "lol"
                puts "lol"
               end # one
            end # two
          EOM
          search.call

          expect(search.invalid_blocks.join).to eq(<<~EOM)
            Foo.call
            end # two
          EOM
        end

        it "stacked ends 2" do
          search = CodeSearch.new(<<~EOM)
            def cat
              blerg
            end

            Foo.call do
            end # one
            end # two

            def dog
            end
          EOM
          search.call

          expect(search.invalid_blocks.join).to eq(<<~EOM)
            Foo.call do
            end # one
            end # two

          EOM
        end

        it "stacked ends " do
          search = CodeSearch.new(<<~EOM)
            Foo.call
              def foo
                puts "lol"
                puts "lol"
            end
            end
          EOM
          search.call

          expect(search.invalid_blocks.join).to eq(<<~EOM)
            Foo.call
            end
          EOM
        end

        it "missing space before end" do
          search = CodeSearch.new(<<~EOM)
            Foo.call

              def foo
                puts "lol"
                puts "lol"
             end
            end
          EOM
          search.call

          # expand-1 and expand-2 seem to be broken?
          expect(search.invalid_blocks.join).to eq(<<~EOM)
            Foo.call
            end
          EOM
        end
      end
    end

    it "returns syntax error in outer block without inner block" do
      search = CodeSearch.new(<<~EOM)
        Foo.call
          def foo
            puts "lol"
            puts "lol"
          end # one
        end # two
      EOM
      search.call

      expect(search.invalid_blocks.join).to eq(<<~EOM)
        Foo.call
        end # two
      EOM
    end

    it "doesn't just return an empty `end`" do
      search = CodeSearch.new(<<~EOM)
        Foo.call
        end
      EOM
      search.call

      expect(search.invalid_blocks.join).to eq(<<~EOM)
        Foo.call
        end
      EOM
    end

    it "finds multiple syntax errors" do
      search = CodeSearch.new(<<~EOM)
        describe "hi" do
          Foo.call
          end
        end

        it "blerg" do
          Bar.call
          end
        end
      EOM
      search.call

      expect(search.invalid_blocks.join).to eq(<<~EOM.indent(2))
        Foo.call
        end
        Bar.call
        end
      EOM
    end

    it "finds a typo def" do
      search = CodeSearch.new(<<~EOM)
        defzfoo
          puts "lol"
        end
      EOM
      search.call

      expect(search.invalid_blocks.join).to eq(<<~EOM)
        defzfoo
        end
      EOM
    end

    it "finds a mis-matched def" do
      search = CodeSearch.new(<<~EOM)
        def foo
          def blerg
        end
      EOM
      search.call

      expect(search.invalid_blocks.join).to eq(<<~EOM.indent(2))
        def blerg
      EOM
    end

    it "finds a naked end" do
      search = CodeSearch.new(<<~EOM)
        def foo
          end # one
        end # two
      EOM
      search.call

      expect(search.invalid_blocks.join).to eq(<<~EOM.indent(2))
        end # one
      EOM
    end

    it "returns when no invalid blocks are found" do
      search = CodeSearch.new(<<~EOM)
        def foo
          puts 'lol'
        end
      EOM
      search.call

      expect(search.invalid_blocks).to eq([])
    end

    it "expands frontier by eliminating valid lines" do
      search = CodeSearch.new(<<~EOM)
        def foo
          puts 'lol'
        end
      EOM
      search.create_blocks_from_untracked_lines

      expect(search.code_lines.join).to eq(<<~EOM)
        def foo
        end
      EOM
    end

    class BlockDocument
      attr_reader :blocks, :queue

      def initialize(code_lines: )
        @code_lines = code_lines
        @blocks = nil
        @queue = PriorityQueue.new
        @root = nil
      end

      def call
        last = nil
        @blocks = @code_lines.map.with_index do |line, i|
          next if line.empty?


          node = BlockNode.new(lines: line)
          @root ||= node
          queue << node
          node.above = last
          last&.below = node
          last = node
          node
        end

        if node = @blocks[-2]
          node.below = @blocks[-1]
        end

        self
      end

      def eat_above(node)
        return unless now = node&.eat_above

        if node.above == @root
          @root = now
        end

        node.above.delete
        node.delete

        while queue&.peek&.deleted?
          queue.pop
        end

        now
      end

      def eat_below(node)
        eat_above(node&.below)
      end

      def pop
        @queue.pop
      end

      def peek
        @queue.peek
      end
    end

    class BlockNode
      attr_accessor :above, :below
      attr_reader :lines, :start_index, :end_index, :parents, :lex_diff

      def initialize(lines: , parents: nil)
        lines = Array(lines)
        parents = Array(parents)
        @lines = lines
        @parents = parents

        if @parents.empty?
          @start_index = lines.first.index
          @end_index = lines.last.index
          set_lex_diff_from(@lines)
        else
          @lex_diff = LexPairDiff.new_empty
          @parents.each do |p|
            @lex_diff.concat(p.lex_diff)
          end
          @start_index = @parents.first.start_index
          @end_index = @parents.last.end_index
        end
        @deleted = false

      end

      def delete
        @deleted = true
      end

      def deleted?
        @deleted
      end

      def valid?
        return @valid if defined?(@valid)

        @valid = DeadEnd.valid?(@lines.join)
      end

      def unbalanced?
        !balanced?
      end

      def balanced?
        @lex_diff.balanced?
      end

      def leaning
        @lex_diff.leaning
      end

      def to_s
        @lines.join
      end

      def <=>(other)
        case indent <=> other.indent
        when 1 then 1
        when -1 then -1
        when 0
          end_index <=> other.end_index
        end
      end

      def indent
        @indent ||= lines.map(&:indent).min || 0
      end

      def inspect
        "#<DeadEnd::BlockNode 0x000000010cbfelol #{@start_index}..#{@end_index} >"
      end

      private def set_lex_diff_from(lines)
        @lex_diff = LexPairDiff.new_empty
        lines.each do |line|
          @lex_diff.concat(line.lex_diff)
        end
      end

      def eat_above
        return nil if above.nil?

        node = BlockNode.new(lines: above.lines + lines, parents: [above, self])
        if above.above
          node.above = above.above
          above.above.below = node
        end

        if below
          node.below = below
          below.above = node
        end


        node
      end

      def eat_below
        return nil if below.nil?
        below.eat_above
      end
    end

    it "eats blerg" do
      code_lines = CodeLine.from_source(<<~'EOM')
        def foo
          print "hello"
            end # one
        end # two
      EOM

      document = BlockDocument.new(code_lines: code_lines).call
      node = document.queue.pop
      document.eat_above(node)

      node = document.queue.pop
      document.eat_above(node)
      node = document.queue.pop
      out = document.eat_below(node)

      expect(out.to_s).to eq(code_lines.join)
      expect(out.valid?).to be_falsey
      expect(out.balanced?).to be_falsey
      expect(out.parents.map(&:leaning)).to eq([:left, :right])
    end

    it "eats nodes up" do
      code_lines = CodeLine.from_source(<<~'EOM')
        def foo
          print "hello"
            end # one
        end # two
      EOM

      document = BlockDocument.new(code_lines: code_lines).call
      node = document.queue.pop
      out = node.eat_above
      expect(out.to_s).to eq(<<~'EOM'.indent(2))
        print "hello"
          end # one
      EOM

      expect(out.above.to_s.strip).to eq("def foo")
      expect(out.below.to_s.strip).to eq("end # two")

      expect(out.above.below).to eq(out)
      expect(out.below.above).to eq(out)

      out = out.eat_below
      expect(out.to_s).to eq(<<~'EOM')
          print "hello"
            end # one
        end # two
      EOM

      out = out.eat_above
      expect(out.to_s).to eq(<<~'EOM')
        def foo
          print "hello"
            end # one
        end # two
      EOM

      expect(out.valid?).to be_falsey
      expect(out.balanced?).to be_falsey
      expect(out.parents.map(&:leaning)).to eq([:left, :right])

      frontier = out.parents.dup

      # Find the innermost invalid block
    end

    it "prioritizes indent" do
      code_lines = CodeLine.from_source(<<~'EOM')
        def foo
          end # one
        end # two
      EOM

      document = BlockDocument.new(code_lines: code_lines).call
      one = document.queue.pop
      expect(one.to_s.strip).to eq("end # one")
    end

    it "Block document dequeues from bottom to top" do
      code_lines = CodeLine.from_source(<<~'EOM')
        Foo.call
        end
      EOM

      document = BlockDocument.new(code_lines: code_lines).call
      one = document.queue.pop
      expect(one.to_s.strip).to eq("end")

      two = document.queue.pop
      expect(two.to_s.strip).to eq("Foo.call")

      expect(one.above).to eq(two)
      expect(two.below).to eq(one)

      expect(document.queue.pop).to eq(nil)
    end

  end
end
