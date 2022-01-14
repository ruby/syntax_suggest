# frozen_string_literal: true

require_relative "../spec_helper"

module DeadEnd

  RSpec.describe UpDownExpand do
    it "can handle 'unknown' direction code" do
      source = <<~'EOM'
        parser.on('-r', '--require REQUIRE(S)',
                  'Gems and built-in libraries (e.g. shellwords, yaml) to require, comma separated, or ! to clear') do |v|
          if v == '!'
            options.requires.clear
          else
            v.split(',').map(&:strip).each do |r|
              if r[0] == '-'
                options.requires -= [r[1..-1]]
              else
                options.requires << r
              end
            end
          end
        end
      EOM

      lines = CleanDocument.new(source: source).call.lines
      expand = UpDownExpand.new(
        code_lines: lines,
        block: CodeBlock.new(lines: lines[1])
      )

      expect(expand.direction).to eq(:unknown)
      expand.call
      expect(expand.to_s).to eq(<<~'EOM')
        parser.on('-r', '--require REQUIRE(S)',
                  'Gems and built-in libraries (e.g. shellwords, yaml) to require, comma separated, or ! to clear') do |v|
          if v == '!'
      EOM

      expand.call
      expect(expand.to_s).to eq(<<~'EOM')
        parser.on('-r', '--require REQUIRE(S)',
                  'Gems and built-in libraries (e.g. shellwords, yaml) to require, comma separated, or ! to clear') do |v|
          if v == '!'
            options.requires.clear
          else
            v.split(',').map(&:strip).each do |r|
              if r[0] == '-'
                options.requires -= [r[1..-1]]
              else
                options.requires << r
              end
            end
          end
        end
      EOM
    end

    it "does not generate (known) invalid blocks when started at different positions" do
      source = <<~EOM
        Foo.call do |a
          # inner
        end # one

        print lol
        class Foo
        end # two
      EOM
      lines = CodeLine.from_source(source)
      expand = UpDownExpand.new(
        code_lines: lines,
        block: CodeBlock.new(lines: lines[1])
      )
      expect(expand.direction).to eq(:equal)
      expand.call
      expect(expand.to_s).to eq(<<~'EOM')
        Foo.call do |a
          # inner
        end # one

        print lol
      EOM

      expand = UpDownExpand.new(
        code_lines: lines,
        block: CodeBlock.new(lines: lines[0])
      )
      expect(expand.call.to_s).to eq(<<~'EOM')
        Foo.call do |a
          # inner
        end # one
      EOM

      expand = UpDownExpand.new(
        code_lines: lines,
        block: CodeBlock.new(lines: lines[2])
      )
      expect(expand.direction).to eq(:up)

      expand.call

      expect(expand.to_s).to eq(<<~'EOM')
        Foo.call do |a
          # inner
        end # one
      EOM

      expand = UpDownExpand.new(
        code_lines: lines,
        block: CodeBlock.new(lines: lines[3])
      )
      expect(expand.direction).to eq(:equal)
      expand.call
      expect(expand.to_s).to eq(<<~'EOM')
        Foo.call do |a
          # inner
        end # one

        print lol
      EOM

      expand = UpDownExpand.new(
        code_lines: lines,
        block: CodeBlock.new(lines: lines[4])
      )
      expect(expand.direction).to eq(:equal)
      expand.call
      expect(expand.to_s).to eq(<<~'EOM')
        Foo.call do |a
          # inner
        end # one

        print lol
      EOM

      expand = UpDownExpand.new(
        code_lines: lines,
        block: CodeBlock.new(lines: lines[5])
      )
      expect(expand.direction).to eq(:down)
      expand.call
      expect(expand.to_s).to eq(<<~'EOM')
        class Foo
        end # two
      EOM
    end

    it "expands" do
      source = <<~EOM
        class Blerg
          Foo.call do |a
          end # one

          print lol
          class Foo
          end # two
        end # three
      EOM
      lines = CodeLine.from_source(source)
      expand = UpDownExpand.new(
        code_lines: lines,
        block: CodeBlock.new(lines: lines[5])
      )
      expect(expand.call.to_s).to eq(<<~'EOM'.indent(2))
        class Foo
        end # two
      EOM
      expect(expand.call.to_s).to eq(<<~'EOM'.indent(2))
        Foo.call do |a
        end # one

        print lol
        class Foo
        end # two
      EOM

      expect(expand.call.to_s).to eq(<<~'EOM')
        class Blerg
          Foo.call do |a
          end # one

          print lol
          class Foo
          end # two
        end # three
      EOM
    end

    it "expands up when on an end" do
      lines = CodeLine.from_source(<<~'EOM')
        Foo.new do
        end
      EOM
      expand = UpDownExpand.new(
        code_lines: lines,
        block: CodeBlock.new(lines: lines[1])
      )
      expect(expand.direction).to eq(:up)
      expand.call
      expect(expand.direction).to eq(:stop)

      expect(expand.start_index).to eq(0)
      expect(expand.end_index).to eq(1)
      expect(expand.to_s).to eq(lines.join)
    end

    it "expands down when on a keyword" do
      lines = CodeLine.from_source(<<~'EOM')
        Foo.new do
        end
      EOM
      expand = UpDownExpand.new(
        code_lines: lines,
        block: CodeBlock.new(lines: lines[0])
      )
      expect(expand.direction).to eq(:down)
      expand.call
      expect(expand.direction).to eq(:stop)

      expect(expand.start_index).to eq(0)
      expect(expand.end_index).to eq(1)
      expect(expand.to_s).to eq(lines.join)
    end
  end
end
