require_relative "../spec_helper.rb"

module SyntaxErrorSearch
  RSpec.describe CodeBlock do
    it "expand until next boundry (indentation)" do
      source_string = <<~EOM
        describe "what" do
          Foo.call
        end

        describe "hi"
          Bar.call do
            Foo.call
          end
        end

        it "blerg" do
        end
      EOM

      source = CodeSource.new(source_string)
      block = CodeBlock.new(
        lines: source.code_lines[6],
        source: source
      )

      block.expand_until_next_boundry

      expect(block.to_s).to eq(<<~EOM.indent(2))
        Bar.call do
          Foo.call
        end
      EOM

      block.expand_until_next_boundry

      expect(block.to_s).to eq(<<~EOM)

        describe "hi"
          Bar.call do
            Foo.call
          end
        end

      EOM
    end

    it "expand until next boundry (empty lines)" do
      source_string = <<~EOM
        describe "what" do
        end

        describe "hi"
        end

        it "blerg" do
        end
      EOM

      source = CodeSource.new(source_string)
      block = CodeBlock.new(
        lines: source.code_lines[0],
        source: source
      )
      block.expand_until_next_boundry

      expect(block.to_s.strip).to eq(<<~EOM.strip)
        describe "what" do
        end
      EOM

      source = CodeSource.new(source_string)
      block = CodeBlock.new(
        lines: source.code_lines[3],
        source: source
      )
      block.expand_until_next_boundry

      expect(block.to_s.strip).to eq(<<~EOM.strip)
        describe "hi"
        end
      EOM

      block.expand_until_next_boundry

      expect(block.to_s.strip).to eq(source_string.strip)
    end

    it "can detect if it's valid or not" do
      code_lines = code_line_array(<<~EOM)
        def foo
          puts 'lol'
        end
      EOM

      block = CodeBlock.new(source: Object.new, lines: code_lines[1])
      expect(block.valid?).to be_truthy
    end

    it "can be sorted in indentation order" do
      code_lines = code_line_array(<<~EOM)
        def foo
          puts 'lol'
            end
      EOM

      block_0 = CodeBlock.new(source: Object.new, lines: code_lines[0])
      block_1 = CodeBlock.new(source: Object.new, lines: code_lines[1])
      block_2 = CodeBlock.new(source: Object.new, lines: code_lines[2])

      expect(block_0 <=> block_0).to eq(0)
      expect(block_1 <=> block_0).to eq(1)
      expect(block_1 <=> block_2).to eq(-1)

      array = [block_2, block_1, block_0].sort
      expect(array.last).to eq(block_2)

      block = CodeBlock.new(source: "", lines: CodeLine.new(line: " " * 8 + "foo", index: 4))
      array.prepend(block)
      expect(array.sort.last).to eq(block)
    end

    it "knows it's current indentation level" do
      code_lines = code_line_array(<<~EOM)
        def foo
          puts 'lol'
        end
      EOM

      block = CodeBlock.new(source: Object.new, lines: code_lines[1])
      expect(block.current_indent).to eq(2)

      block = CodeBlock.new(source: Object.new, lines: code_lines[0])
      expect(block.current_indent).to eq(0)

      # expect(block.document_valid_without?).to be_truthy
      # expect(block.block_without.lines).to eq([source.code_lines[0], source.code_lines[2]])
      # expect(block.before_lines).to eq([source.code_lines[0]])
      # expect(block.before_line).to eq(source.code_lines[0])
      # expect(block.after_lines).to eq([source.code_lines[2]])
      # expect(block.after_line).to eq(source.code_lines[2])
    end


    it "foo" do
      code_lines = code_line_array(<<~EOM)
        def foo
          bar; end
        end
      EOM

      block = CodeBlock.new(source: Object.new, lines: code_lines[1])
      expect(block.valid?).to be_falsey
      # expect(block.document_valid_without?).to be_truthy
      # expect(block.block_without.lines).to eq([source.code_lines[0], source.code_lines[2]])
      # expect(block.before_lines).to eq([source.code_lines[0]])
      # expect(block.after_lines).to eq([source.code_lines[2]])
    end
  end
end
