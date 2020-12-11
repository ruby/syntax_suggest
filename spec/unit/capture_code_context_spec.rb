# frozen_string_literal: true

require_relative "../spec_helper.rb"

module DeadEnd
  RSpec.describe CaptureCodeContext do
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
      lines = display.call.sort
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
