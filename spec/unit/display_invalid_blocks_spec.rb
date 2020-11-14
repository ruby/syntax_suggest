# frozen_string_literal: true

require_relative "../spec_helper.rb"

module SyntaxErrorSearch
  RSpec.describe DisplayInvalidBlocks do
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
         ["❯ 2  ", display.terminal_highlight, "  def hello"].join,
          "  3    def hai",
          "  4    end",
          "  5  end",
          ""
        ].join($/ + display.terminal_end)
      )
    end
  end
end
