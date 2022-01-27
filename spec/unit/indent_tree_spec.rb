# frozen_string_literal: true

require_relative "../spec_helper"

module DeadEnd
  RSpec.describe IndentTree do
    it "WIP syntax_tree.rb.txt for performance validation" do
      file = fixtures_dir.join("syntax_tree.rb.txt")
      lines = file.read.lines
      lines.delete_at(768 - 1)
      source = lines.join

      debug_perf do
        code_lines = CleanDocument.new(source: source).call.lines
        document = BlockDocument.new(code_lines: code_lines).call
        tree = IndentTree.new(document: document).call
      end
    end

    it "invalid if/else end with surrounding code" do
      source = <<~'EOM'
        class Foo
          def to_json(*opts)
            { type: :args, parts: parts, loc: location }.to_json(*opts)
          end
        end

        def on_args_add(arguments, argument)
          if arguments.parts.empty?
            Args.new(parts: [argument], location: argument.location)
          else

            Args.new(
              parts: arguments.parts << argument,
              location: arguments.location.to(argument.location)
            )
          end
          # Missing end here, comments are erased via CleanDocument

        class ArgsAddBlock
          attr_reader :arguments

          attr_reader :block

          attr_reader :location

          def initialize(arguments:, block:, location:)
            @arguments = arguments
            @block = block
            @location = location
          end
        end
      EOM

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call

      blocks = document.to_a
      expect(blocks.length).to eq(1)
      expect(document.root.leaning).to eq(:left)
      expect(document.root.inner[0].to_s).to eq(<<~'EOM')
        class Foo
          def to_json(*opts)
            { type: :args, parts: parts, loc: location }.to_json(*opts)
          end
        end
      EOM
      expect(document.root.inner[0].leaning).to eq(:equal)
      expect(document.root.inner[1].inner[0].to_s).to eq(<<~'EOM')
        def on_args_add(arguments, argument)
      EOM
      expect(document.root.inner[1].inner[0].leaning).to eq(:left)

      expect(document.root.inner[1].inner[1].to_s).to eq(<<~'EOM'.indent(2))
        if arguments.parts.empty?
          Args.new(parts: [argument], location: argument.location)
        else
          Args.new(
            parts: arguments.parts << argument,
            location: arguments.location.to(argument.location)
          )
        end
      EOM

      expect(document.root.inner[1].inner[2].to_s).to eq(<<~'EOM')
        class ArgsAddBlock
          attr_reader :arguments
          attr_reader :block
          attr_reader :location
          def initialize(arguments:, block:, location:)
            @arguments = arguments
            @block = block
            @location = location
          end
        end
      EOM
      expect(document.root.inner[1].inner[1].leaning).to eq(:equal)
    end

    it "valid if/else end" do
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
        end
      EOM

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call

      blocks = document.to_a
      expect(blocks.length).to eq(1)
      expect(document.root.leaning).to eq(:equal)
      expect(document.root.inner.length).to eq(3)
      expect(document.root.inner[0].to_s).to eq(<<~'EOM')
        def on_args_add(arguments, argument)
      EOM

      expect(document.root.inner[1].to_s).to eq(<<~'EOM'.indent(2))
        if arguments.parts.empty?
          Args.new(parts: [argument], location: argument.location)
        else
          Args.new(
            parts: arguments.parts << argument,
            location: arguments.location.to(argument.location)
          )
        end
      EOM

      expect(document.root.inner[2].to_s).to eq(<<~'EOM')
        end
      EOM

      inside = document.root.inner[1]
      expect(inside.inner.length).to eq(5)
      expect(inside.inner[0].to_s).to eq(<<~'EOM'.indent(2))
        if arguments.parts.empty?
      EOM

      expect(inside.inner[1].to_s).to eq(<<~'EOM'.indent(4))
          Args.new(parts: [argument], location: argument.location)
      EOM

      expect(inside.inner[2].to_s).to eq(<<~'EOM'.indent(2))
        else
      EOM

      expect(inside.inner[3].to_s).to eq(<<~'EOM'.indent(4))
          Args.new(
            parts: arguments.parts << argument,
            location: arguments.location.to(argument.location)
          )
      EOM

      expect(inside.inner[4].to_s).to eq(<<~'EOM'.indent(2))
        end
      EOM
    end

    it "extra space before end" do
      source = <<~'EOM'
        Foo.call
          def foo
            print "lol"
            print "lol"
           end # one
        end # two
      EOM
      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call

      blocks = document.to_a
      expect(blocks.length).to eq(1)
      expect(document.root.leaning).to eq(:right)

      expect(document.root.inner.length).to eq(3)
      expect(document.root.inner[0].to_s).to eq(<<~'EOM')
        Foo.call
      EOM
      expect(document.root.inner[0].indent).to eq(0)
      expect(document.root.inner[1].to_s).to eq(<<~'EOM'.indent(2))
        def foo
          print "lol"
          print "lol"
         end # one
      EOM
      expect(document.root.inner[1].balanced?).to be_truthy
      expect(document.root.inner[1].indent).to eq(2)

      expect(document.root.inner[2].to_s).to eq(<<~'EOM')
        end # two
      EOM
      expect(document.root.inner[2].indent).to eq(0)
    end

    it "captures complicated" do
      source = <<~'EOM'
        if true              # 0
          print 'huge 1'     # 1
        end                  # 2

        if true              # 4
          print 'huge 2'     # 5
        end                  # 6

        if true              # 8
          print 'huge 3'     # 9
        end                  # 10
      EOM

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document)
      tree.call

      blocks = document.to_a
      expect(blocks.length).to eq(1)

      expect(document.root.inner.length).to eq(3)
      expect(document.root.inner[0].to_s).to eq(<<~'EOM')
        if true              # 0
          print 'huge 1'     # 1
        end                  # 2
      EOM

      expect(document.root.inner[1].to_s).to eq(<<~'EOM')
        if true              # 4
          print 'huge 2'     # 5
        end                  # 6
      EOM

      expect(document.root.inner[2].to_s).to eq(<<~'EOM')
        if true              # 8
          print 'huge 3'     # 9
        end                  # 10
      EOM
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

    it "captures" do
      source = <<~'EOM'
        if true
          print 'huge 1'
          print 'huge 2'
          print 'huge 3'
        end
      EOM

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document)
      tree.call

      # blocks = document.to_a
      expect(document.root.to_s).to eq(code_lines.join)
      expect(document.to_a.length).to eq(1)
      expect(document.root.inner.length).to eq(3)
    end

    it "simple" do
      skip
      source = <<~'EOM'
        print 'lol'
        print 'lol'

        Foo.call # missing do
        end
      EOM

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      search = BlockSearch.new(document: document).call
      search.call

      expect(search.document.root).to eq(
        BlockNode.new(lines: code_lines[0..1], indent: 0).tap { |node|
          node.inner << BlockNode.new(lines: code_lines[0], indent: 0)
          node.right = BlockNode.new(lines: code_lines[1], indent: 0)
        }
      )
    end
  end
end
