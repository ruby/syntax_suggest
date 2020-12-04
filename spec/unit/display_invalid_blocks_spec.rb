# frozen_string_literal: true

require_relative "../spec_helper.rb"

module SyntaxErrorSearch
  RSpec.describe DisplayInvalidBlocks do
    it "captures surrounding context on same indent" do
      syntax_string = <<~EOM
        class Blerg
        end
        class OH

          def lol
          end

          it "foo"
          end

          def haha
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
      expect(lines.select(&:hidden?).map(&:line_number)).to eq([11, 12])

      out = DisplayCodeWithLineNumbers.new(
        lines: lines,
      ).call

      expect(out).to eq(<<~EOM.indent(2))
         3  class OH
         5    def lol
         6    end
         8    it "foo"
         9    end
        11    def haha
        12    end
        14  end
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
      lines = display.call.sort
      expect(lines.join).to eq(<<~EOM)
        class OH
          def hello
            it "foo" do
          end
        end
      EOM
    end

    it "works with valid code" do
      syntax_string = <<~EOM
        class OH
          def hello
          end
          def hai
          end
        end
      EOM

      search = CodeSearch.new(syntax_string)
      search.call
      io = StringIO.new
      display = DisplayInvalidBlocks.new(
        io: io,
        blocks: search.invalid_blocks,
        terminal: false,
        code_lines: search.code_lines,
      )
      display.call
      expect(io.string).to include("Syntax OK")
    end

    it "outputs to io when using `call`" do
      code_lines = code_line_array(<<~EOM)
        class OH
          def hello
          def hai
          end
        end
      EOM

      io = StringIO.new
      block = CodeBlock.new(lines: code_lines[1])
      display = DisplayInvalidBlocks.new(
        io: io,
        blocks: block,
        terminal: false,
        code_lines: code_lines,
      )
      display.call
      expect(io.string).to include("❯ 2    def hello")
      expect(io.string).to include("SyntaxSearch")
    end

    it " wraps code with github style codeblocks" do
      code_lines = code_line_array(<<~EOM)
        class OH
          def hello
          def hai
          end
        end
      EOM

      block = CodeBlock.new(lines: code_lines[1])
      display = DisplayInvalidBlocks.new(
        blocks: block,
        terminal: false,
        code_lines: code_lines
      )
      expect(display.code_block).to eq(<<~EOM)
         1  class OH
       ❯ 2    def hello
         3    def hai
         4    end
         5  end
      EOM
    end

    it "shows terminal characters" do
      code_lines = code_line_array(<<~EOM)
        class OH
          def hello
          def hai
          end
        end
      EOM

      block = CodeBlock.new(lines: code_lines[1])
      display = DisplayInvalidBlocks.new(
        blocks: block,
        terminal: false,
        code_lines: code_lines
      )

      expect(display.code_with_lines).to eq(
        [
          "  1  class OH",
          "❯ 2    def hello",
          "  3    def hai",
          "  4    end",
          "  5  end",
          ""
        ].join($/)
      )

      block = CodeBlock.new(lines: code_lines[1])
      display = DisplayInvalidBlocks.new(
        blocks: block,
        terminal: true,
        code_lines: code_lines
      )

      expect(display.code_with_lines).to eq(
        [
          "  1  class OH",
         ["❯ 2  ", DisplayCodeWithLineNumbers::TERMINAL_HIGHLIGHT, "  def hello"].join,
          "  3    def hai",
          "  4    end",
          "  5  end",
          ""
        ].join($/ + DisplayCodeWithLineNumbers::TERMINAL_END)
      )
    end
  end
end
