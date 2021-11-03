# frozen_string_literal: true

require_relative "../spec_helper"

module DeadEnd
  class CurrentIndex
    attr_reader :current_indent

    def initialize(value)
      @current_indent = value
    end

    def <=>(value)
      @current_indent <=> value.current_indent
    end
  end

  RSpec.describe CodeFrontier do
    it "lol" do
      frontier = InsertionSort.new
      frontier << CurrentIndex.new(0)
      frontier << CurrentIndex.new(1)

      expect(frontier.to_a.map(&:current_indent)).to eq([0, 1])

      frontier << CurrentIndex.new(1)
      expect(frontier.to_a.map(&:current_indent)).to eq([0, 1, 1])

      frontier << CurrentIndex.new(0)
      expect(frontier.to_a.map(&:current_indent)).to eq([0, 0, 1, 1])

      frontier << CurrentIndex.new(10)
      expect(frontier.to_a.map(&:current_indent)).to eq([0, 0, 1, 1, 10])

      frontier << CurrentIndex.new(2)
      expect(frontier.to_a.map(&:current_indent)).to eq([0, 0, 1, 1, 2, 10])
    end

    it "fffff" do
      frontier = InsertionSort.new
values = [18,18,0,18,0,18,18,18,18,16,18,8,18,8,8,8,16,6,0,0,16,16,4,14,14,12,12,12,10,12,12,12,12,8,10,10,8,8,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,8,10,6,6,6,6,6,6,8,10,8,8,10,8,10,8,10,8,6,8,8,6,8,6,6,8,0,8,0,0,8,8,0,8,0,8,8,0,8,8,8,0,8,0,8,8,8,8,8,8,8,8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,8,8,8,8,6,8,6,6,6,6,8,6,8,6,6,4,4,6,6,4,6,4,6,6,4,6,4,4,6,6,6,6,4,4,4,2,4,4,4,4,4,4,6,6,0,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,0,0,6,6,2]
values.each do |v|
  frontier << CurrentIndex.new(v)
end

      expect(frontier.to_a.map(&:current_indent)).to eq(values.sort)
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
      blocks << CodeBlock.new(lines: code_lines[1])
      blocks << CodeBlock.new(lines: code_lines[5])
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
          [:a], [:b], [:c], [:d],
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

    it "doesn't duplicate blocks" do
      code_lines = code_line_array(<<~EOM)
        def foo
          puts "lol"
          puts "lol"
          puts "lol"
        end
      EOM

      frontier = CodeFrontier.new(code_lines: code_lines)
      frontier << CodeBlock.new(lines: [code_lines[2]])
      expect(frontier.count).to eq(1)

      frontier << CodeBlock.new(lines: [code_lines[1], code_lines[2], code_lines[3]])
      expect(frontier.count).to eq(1)
      expect(frontier.pop.to_s).to eq(<<~EOM.indent(2))
        puts "lol"
        puts "lol"
        puts "lol"
      EOM

      code_lines = code_line_array(<<~EOM)
        def foo
          puts "lol"
          puts "lol"
          puts "lol"
        end
      EOM

      frontier = CodeFrontier.new(code_lines: code_lines)
      frontier << CodeBlock.new(lines: [code_lines[2]])
      expect(frontier.count).to eq(1)

      frontier << CodeBlock.new(lines: [code_lines[3]])
      expect(frontier.count).to eq(2)
      expect(frontier.pop.to_s).to eq(<<~EOM.indent(2))
        puts "lol"
      EOM
    end

    it "detects if multiple syntax errors are found" do
      code_lines = code_line_array(<<~EOM)
        def foo
          end
        end
      EOM

      frontier = CodeFrontier.new(code_lines: code_lines)

      frontier << CodeBlock.new(lines: code_lines[1])
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
      frontier << CodeBlock.new(lines: [code_lines[1]])
      block = frontier.pop
      expect(block.to_s).to eq(<<~EOM.indent(2))
        puts "lol"
      EOM
      frontier << block

      expect(frontier.holds_all_syntax_errors?).to be_falsey
    end
  end
end
