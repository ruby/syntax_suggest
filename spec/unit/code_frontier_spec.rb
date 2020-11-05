require_relative "../spec_helper.rb"

module SyntaxErrorSearch
  RSpec.describe CodeFrontier do
    it "search example" do
      code_lines = code_line_array(<<~EOM)
        describe "lol" do
          foo
          end
        end

        it "lol" do
          bar
          end
        end
      EOM

      frontier = CodeFrontier.new(code_lines: code_lines)

      until frontier.holds_all_syntax_errors?
        block = frontier.pop

        if block.valid?
          block.lines.each(&:mark_invisible)

        else
          block.expand_until_neighbors
          frontier << block
        end
      end

      expect(frontier.detect_invalid_blocks.join).to eq(<<~EOM.indent(2))
        foo
        end
        bar
        end
      EOM
    end
    it "detect_bad_blocks" do
      code_lines = code_line_array(<<~EOM)
        describe "lol" do
          end
        end

        it "lol" do
          end
        end
      EOM

      frontier = CodeFrontier.new(code_lines: code_lines)
      blocks = []
      blocks << CodeBlock.new(lines: code_lines[1], code_lines: code_lines)
      blocks << CodeBlock.new(lines: code_lines[5], code_lines: code_lines)
      blocks.each do |b|
        frontier << b
      end

      expect(frontier.detect_invalid_blocks).to eq(blocks)
    end

    it "self.combination" do
      expect(
        CodeFrontier.combination([:a, :b, :c, :d])
      ).to eq(
        [
          [:a],[:b],[:c],[:d],
          [:a, :b],
          [:a, :c],
          [:a, :d],
          [:b, :c],
          [:b, :d],
          [:c, :d],
          [:a, :b, :c],
          [:a, :b, :d],
          [:a, :c, :d],
          [:b, :c, :d],
          [:a, :b, :c, :d]
        ]
      )
    end

    it "detects if multiple syntax errors are found" do
      code_lines = code_line_array(<<~EOM)
        def foo
          end
        end
      EOM

      frontier = CodeFrontier.new(code_lines: code_lines)
      block = frontier.pop
      expect(block.to_s).to eq(<<~EOM.indent(2))
        end
      EOM
      frontier << block

      expect(frontier.holds_all_syntax_errors?).to be_truthy
    end

    it "detects if it has not captured all syntax errors" do
      code_lines = code_line_array(<<~EOM)
        def foo
          puts "lol"
        end

        describe "lol"
        end

        it "lol"
        end
      EOM

      frontier = CodeFrontier.new(code_lines: code_lines)
      block = frontier.pop
      expect(block.to_s).to eq(<<~EOM.indent(2))
        puts "lol"
      EOM
      frontier << block

      expect(frontier.holds_all_syntax_errors?).to be_falsey
    end

    it "generates a block when popping" do
      code_lines = code_line_array(<<~EOM)
        def foo
          puts "lol1"
          puts "lol2"
          puts "lol3"

          puts "lol4"
        end
      EOM

      frontier = CodeFrontier.new(code_lines: code_lines)
      expect(frontier.pop.to_s).to eq(<<~EOM.indent(2))
        puts "lol1"
        puts "lol2"
        puts "lol3"

      EOM

      expect(frontier.generate_new_block?).to be_truthy

      expect(frontier.pop.to_s).to eq(<<~EOM.indent(2))

        puts "lol4"
      EOM

      expect(frontier.pop.to_s).to eq(<<~EOM)
        def foo
      EOM
    end

    it "generates continuous block lines" do
      code_lines = code_line_array(<<~EOM)
        def foo
          puts "lol1"
          puts "lol2"
          puts "lol3"

          puts "lol4"
        end
      EOM

      frontier = CodeFrontier.new(code_lines: code_lines)
      block = frontier.next_block
      expect(block.to_s).to eq(<<~EOM.indent(2))
          puts "lol1"
          puts "lol2"
          puts "lol3"

      EOM

      expect(frontier.generate_new_block?).to be_truthy

      frontier << block

      block = frontier.next_block
      expect(block.to_s).to eq(<<~EOM.indent(2))

          puts "lol4"
      EOM
      frontier << block

      expect(frontier.generate_new_block?).to be_falsey
    end

    it "detects empty" do
      code_lines = code_line_array(<<~EOM)
        def foo
          puts "lol"
        end
      EOM

      frontier = CodeFrontier.new(code_lines: code_lines)

      expect(frontier.empty?).to be_falsey
      expect(frontier.any?).to be_truthy

      frontier = CodeFrontier.new(code_lines: [])

      expect(frontier.empty?).to be_truthy
      expect(frontier.any?).to be_falsey
    end
  end
end
