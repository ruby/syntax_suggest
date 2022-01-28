# frozen_string_literal: true

require_relative "../spec_helper"

module DeadEnd
  RSpec.describe IndentTree do
    it "regression dog test" do
      source = <<~'EOM'
        class Dog
          def bark
            puts "woof"
        end
      EOM
      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call

      node = tree.root
      expect(node.outer_nodes.valid?).to be_truthy
      expect(node.inner_nodes.valid?).to be_falsey
      node = node.inner_nodes.parents[0]

      expect(node.outer_nodes.valid?).to be_falsey
      expect(node.inner_nodes.valid?).to be_truthy

      expect(node.outer_nodes.to_s).to eq(<<~'EOM'.indent(2))
        def bark
      EOM
    end

    it "regression test ambiguous end" do
      # Even though you would think the first step is to
      # expand the "print" line, we base priority off of
      # "next_indent" so the actual highest "next indent" line
      # comes from "end # one" which captures "print", then it
      # expands out from there
      source = <<~'EOM'
        def call
            print "lol"
          end # one
        end # two
      EOM

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call

      node = tree.root
      expect(node.outer_nodes.valid?).to be_truthy
      expect(node.outer_nodes.to_s).to eq(<<~'EOM')
        def call
        end # two
      EOM

      expect(node.inner_nodes.valid?).to be_falsey
      expect(node.inner_nodes.to_s).to eq(<<~'EOM'.indent(2))
          print "lol"
        end # one
      EOM

      node = node.inner_nodes.parents[0]
      expect(node.outer_nodes.valid?).to be_falsey
      expect(node.inner_nodes.valid?).to be_truthy
      expect(node.outer_nodes.to_s).to eq(<<~'EOM'.indent(2))
      end # one
      EOM
    end

    it "squished do regression" do
      source = <<~'EOM'
        def call
          trydo

            @options = CommandLineParser.new.parse

            options.requires.each { |r| require!(r) }
            load_global_config_if_exists
            options.loads.each { |file| load(file) }

            @user_source_code = ARGV.join(' ')
            @user_source_code = 'self' if @user_source_code == ''

            @callable = create_callable

            init_rexe_context
            init_parser_and_formatters

            # This is where the user's source code will be executed; the action will in turn call `execute`.
            lookup_action(options.input_mode).call unless options.noop

            output_log_entry
          end # one
        end # two
      EOM

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call

      node = tree.root

      expect(node.outer_nodes.valid?).to be_truthy
      expect(node.inner_nodes.valid?).to be_falsey

      node = node.inner_nodes.parents[0]
      expect(node.inner_nodes.valid?).to be_truthy
      expect(node.outer_nodes.valid?).to be_falsey
      expect(node.outer_nodes.to_s).to eq(<<~'EOM'.indent(2))
        trydo
        end # one
      EOM
    end

    it "rexe regression" do
      lines = fixtures_dir.join("rexe.rb.txt").read.lines
      lines.delete_at(148 - 1)
      source = lines.join

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call

      node = tree.root
      expect(node.outer_nodes.valid?).to be_falsey
      expect(node.parents.map(&:valid?)).to eq([true] * 5 + [false])

      node = node.parents.last
      expect(node.parents.map(&:valid?)).to eq([false, true, true])

      node = node.parents.first
      expect(node.outer_nodes.valid?).to be_truthy
      node = node.inner_nodes.parents[0]
      expect(node.parents.map(&:valid?)).to eq([true, true, true, true, false])

      node = node.parents.last
      expect(node.parents.map(&:valid?)).to eq([false, true, true])

      node = node.parents.first
      expect(node.outer_nodes.valid?).to be_truthy

      node = node.inner_nodes.parents[0]
      expect(node.parents.map(&:valid?)).to eq([true, true, true, true, true, false, true])
      node = node.parents[5]
      expect(node.to_s).to eq(<<~'EOM'.indent(4))
        def format_requires
      EOM
    end

    it "WIP syntax_tree.rb.txt for performance validation" do
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
      end

      expect(tree.to_a.length).to eq(1)
      expect(tree.root.parents.length).to eq(3)
      expect(tree.root.parents[0].to_s).to eq(<<~'EOM')
        require 'ripper'
      EOM

      expect(tree.root.parents[1].to_s).to eq(<<~'EOM')
        require_relative 'syntax_tree/version'
      EOM

      inner = tree.root.parents[2]
      expect(inner.outer_nodes.to_s).to eq(<<~'EOM')
        class SyntaxTree < Ripper
        end
      EOM
      expect(inner.outer_nodes.valid?).to be_truthy
      expect(inner.inner_nodes.valid?).to be_falsey

      inner = inner.inner_nodes

      expect(inner.parents[0].parents.length).to eq(31)
      expect(inner.parents[0].parents.map(&:valid?)).to eq([true] * 30 + [false])

      inner = inner.parents[0].parents.last

      expect(inner.parents[0].parents.length).to eq(183)
      expect(inner.parents[0].parents.map(&:valid?)).to eq([false] + [true] * 182)

      inner = inner.parents[0].parents.first
      expect(inner.to_s).to eq(<<~'EOM'.indent(2))
        def on_args_add(arguments, argument)
      EOM
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
      expect(document.root.parents[0].to_s).to eq(<<~'EOM')
        class Foo
          def to_json(*opts)
            { type: :args, parts: parts, loc: location }.to_json(*opts)
          end
        end
      EOM
      expect(document.root.parents[0].leaning).to eq(:equal)
      expect(document.root.parents[1].parents[0].to_s).to eq(<<~'EOM')
        def on_args_add(arguments, argument)
      EOM
      expect(document.root.parents[1].parents[0].leaning).to eq(:left)

      expect(document.root.parents[1].parents[1].to_s).to eq(<<~'EOM'.indent(2))
        if arguments.parts.empty?
          Args.new(parts: [argument], location: argument.location)
        else
          Args.new(
            parts: arguments.parts << argument,
            location: arguments.location.to(argument.location)
          )
        end
      EOM

      expect(document.root.parents[1].parents[2].to_s).to eq(<<~'EOM')
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
      expect(document.root.parents[1].parents[1].leaning).to eq(:equal)
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
      expect(document.root.parents.length).to eq(3)
      expect(document.root.parents[0].to_s).to eq(<<~'EOM')
        def on_args_add(arguments, argument)
      EOM

      expect(document.root.parents[1].to_s).to eq(<<~'EOM'.indent(2))
        if arguments.parts.empty?
          Args.new(parts: [argument], location: argument.location)
        else
          Args.new(
            parts: arguments.parts << argument,
            location: arguments.location.to(argument.location)
          )
        end
      EOM

      expect(document.root.parents[2].to_s).to eq(<<~'EOM')
        end
      EOM

      inside = document.root.parents[1]
      expect(inside.parents.length).to eq(5)
      expect(inside.parents[0].to_s).to eq(<<~'EOM'.indent(2))
        if arguments.parts.empty?
      EOM

      expect(inside.parents[1].to_s).to eq(<<~'EOM'.indent(4))
          Args.new(parts: [argument], location: argument.location)
      EOM

      expect(inside.parents[2].to_s).to eq(<<~'EOM'.indent(2))
        else
      EOM

      expect(inside.parents[3].to_s).to eq(<<~'EOM'.indent(4))
          Args.new(
            parts: arguments.parts << argument,
            location: arguments.location.to(argument.location)
          )
      EOM

      expect(inside.parents[4].to_s).to eq(<<~'EOM'.indent(2))
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

      expect(document.root.parents.length).to eq(3)
      expect(document.root.parents[0].to_s).to eq(<<~'EOM')
        Foo.call
      EOM
      expect(document.root.parents[0].indent).to eq(0)
      expect(document.root.parents[1].to_s).to eq(<<~'EOM'.indent(2))
        def foo
          print "lol"
          print "lol"
         end # one
      EOM
      expect(document.root.parents[1].balanced?).to be_truthy
      expect(document.root.parents[1].indent).to eq(2)

      expect(document.root.parents[2].to_s).to eq(<<~'EOM')
        end # two
      EOM
      expect(document.root.parents[2].indent).to eq(0)
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

      expect(document.root.parents.length).to eq(3)
      expect(document.root.parents[0].to_s).to eq(<<~'EOM')
        if true              # 0
          print 'huge 1'     # 1
        end                  # 2
      EOM

      expect(document.root.parents[1].to_s).to eq(<<~'EOM')
        if true              # 4
          print 'huge 2'     # 5
        end                  # 6
      EOM

      expect(document.root.parents[2].to_s).to eq(<<~'EOM')
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
      expect(document.root.parents.length).to eq(3)
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
          node.parents << BlockNode.new(lines: code_lines[0], indent: 0)
          node.right = BlockNode.new(lines: code_lines[1], indent: 0)
        }
      )
    end
  end
end
