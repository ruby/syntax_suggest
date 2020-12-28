# frozen_string_literal: true

require_relative "../spec_helper.rb"

module DeadEnd
  RSpec.describe CaptureCodeContext do
    it "shows ends of captured block" do
      lines = fixtures_dir.join("rexe.rb.txt").read.lines
      lines.delete_at(148 - 1)
      source = lines.join

      search = CodeSearch.new(source)
      search.call

      # expect(search.invalid_blocks.join.strip).to eq('class Dog')
      display = CaptureCodeContext.new(
        blocks: search.invalid_blocks,
        code_lines: search.code_lines
      )
      lines = display.call

      lines = lines.sort.map(&:original)
      expect(lines.join).to eq(<<~EOM)
        class Rexe
          VERSION = '1.5.1'
          PROJECT_URL = 'https://github.com/keithrbennett/rexe'
          class Lookups
            def format_requires
          end
          class CommandLineParser
          end
        end
      EOM
    end

    it "shows ends of captured block" do
      source = <<~'EOM'
        class Dog
          def bark
            puts "woof"
        end
      EOM
      search = CodeSearch.new(source)
      search.call

      expect(search.invalid_blocks.join.strip).to eq('class Dog')
      display = CaptureCodeContext.new(
        blocks: search.invalid_blocks,
        code_lines: search.code_lines
      )
      lines = display.call.sort.map(&:original)
      expect(lines.join).to eq(<<~EOM)
        class Dog
          def bark
        end
      EOM
    end

    it "captures surrounding context on falling indent" do
      syntax_string = <<~EOM
        class Blerg
        end

        class OH

          def hello
            it "foo" do
          end
        end

        class Zerg
        end
      EOM

      search = CodeSearch.new(syntax_string)
      search.call

      expect(search.invalid_blocks.join.strip).to eq('it "foo" do')

      display = CaptureCodeContext.new(
        blocks: search.invalid_blocks,
        code_lines: search.code_lines
      )
      lines = display.call.sort.map(&:original)
      expect(lines.join).to eq(<<~EOM)
        class OH
          def hello
            it "foo" do
          end
        end
      EOM
    end

    it "captures surrounding context on same indent" do
      syntax_string = <<~EOM
        class Blerg
        end
        class OH

          def nope
          end

          def lol
          end

          it "foo"
            puts "here"
          end

          def haha
          end

          def nope
          end
        end

        class Zerg
        end
      EOM

      search = CodeSearch.new(syntax_string)
      search.call

      code_context = CaptureCodeContext.new(
        blocks: search.invalid_blocks,
        code_lines: search.code_lines
      )

      # Finds lines previously hidden
      lines = code_context.call
      # expect(lines.select(&:hidden?).map(&:line_number)).to eq([11, 12])

      out = DisplayCodeWithLineNumbers.new(
        lines: lines,
      ).call

      expect(out).to eq(<<~EOM.indent(2))
         3  class OH
         8    def lol
         9    end
        11    it "foo"
        13    end
        15    def haha
        16    end
        20  end
      EOM
    end
  end
end
