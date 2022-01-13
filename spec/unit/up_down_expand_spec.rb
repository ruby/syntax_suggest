# frozen_string_literal: true

require_relative "../spec_helper"

module DeadEnd
  class UpDownExpand
    attr_reader :start_index, :end_index

    def initialize(code_lines: , block: )
      @code_lines = code_lines
      @last_index = @code_lines.length - 1
      @block = block
      @lex_count = LeftRightLexCount.new
      @lex_count.count_lines(block.lines)

      @start_index = block.lines.first.index
      @end_index = block.lines.last.index
    end

    def to_s
      @code_lines[start_index..end_index].join
    end

    def stop_top?
      @start_index == 0
    end

    def stop_bottom?
      @end_index == @last_index
    end

    def direction
      leaning = @lex_count.leaning
      case leaning
      when :left
        return :stop if stop_bottom?
      when :right
        return :stop if stop_top?
      when :equal, :unknown
        if stop_top? && stop_bottom?
          return :stop
        elsif stop_top? && !stop_bottom?
          return :right
        elsif !stop_top? && stop_bottom?
          return :left
        end
      end

      leaning
    end

    def call
      case direction
      when :right
        while direction == :right
          expand_up
        end
      when :left
        while direction == :left
          expand_down
        end
      when :equal
        while direction == :equal
          expand_up
        end
        call
      when :unkown
        # Go slowly and in both directions?
        # stop at the next set of new matched pairs
      when :stop
        return
      end

      self
    end

    def expand_up
      @start_index -= 1
      @code_lines[@start_index].lex.each do |lex|
        @lex_count.count_lex(lex)
      end
    end

    def expand_down
      @end_index += 1
      @code_lines[@end_index].lex.each do |lex|
        @lex_count.count_lex(lex)
      end
    end
  end
  RSpec.describe UpDownExpand do
    it "expands up when on an end" do
      lines = CodeLine.from_source(<<~'EOM')
        Foo.new do
        end
      EOM
      expand = UpDownExpand.new(
        code_lines: lines,
        block: CodeBlock.new(lines: lines[1])
      )
      expect(expand.direction).to eq(:right)
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
      expect(expand.direction).to eq(:left)
      expand.call
      expect(expand.direction).to eq(:stop)

      expect(expand.start_index).to eq(0)
      expect(expand.end_index).to eq(1)
      expect(expand.to_s).to eq(lines.join)
    end
  end
end
