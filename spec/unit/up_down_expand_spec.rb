# frozen_string_literal: true

require_relative "../spec_helper"

module DeadEnd
  class UpDownExpand
    attr_reader :start_index, :end_index

    def initialize(code_lines: , block: )
      @code_lines = code_lines
      @last_index = @code_lines.length - 1
      @block = block

      @lex_diff = nil
      block.lines.each do |line|
        if @lex_diff.nil?
          @lex_diff = line.lex_diff.dup
        else
          @lex_diff.concat(line.lex_diff)
        end
      end

      @start_index = block.lines.first.index
      @end_index = block.lines.last.index
      @last_equal_range = nil
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

    def balanced?
      @lex_diff.balanced?
    end

    def unbalanced?
      !balanced?
    end

    def direction
      leaning = @lex_diff.leaning
      case leaning
      when :left # go down
        if stop_bottom?
          :stop
        else
          :down
        end
      when :right # go up
        if stop_top?
          :stop
        else
          :up
        end
      when :equal, :unknown
        if stop_top? && stop_bottom?
          return :stop
        elsif stop_top? && !stop_bottom?
          return :down
        elsif !stop_top? && stop_bottom?
          return :up
        end
        leaning
      end
    end

    def grab_equal_or
      did_expand = false
      if above && above.lex_diff.balanced?
        did_expand = true
        expand_up
      end

      if below && below.lex_diff.balanced?
        did_expand = true
        expand_down
      end

      return true if did_expand

      if above && below && above.lex_diff.leaning == :left && below.lex_diff.leaning == :right && @lex_diff.dup.concat(above.lex_diff).concat(below.lex_diff).balanced?
        expand_up
        expand_down
        true
      else
        yield
        false
      end
    end

    def call
      case self.direction
      when :up
        # the goal is to become balanced
        while direction == :up && unbalanced?
          expand_up
        end
      when :down
        # the goal is to become balanced
        while direction == :down && unbalanced?
          expand_down
        end
      when :equal
        # Cannot create a balanced expansion, choose to be unbalanced
        while grab_equal_or {
          expand_up unless stop_top?
        }
        end

        call
      when :unkown
        while grab_equal_or {
          expand_up unless stop_top?
          expand_down unless stop_bottom?
        }
        end
      when :stop
        return
      end

      self
    end

    def above
      @code_lines[@start_index - 1] unless stop_top?
    end

    def below
      @code_lines[@end_index + 1] unless stop_bottom?
    end

    def expand_up
      @start_index -= 1
      @lex_diff.concat(@code_lines[@start_index].lex_diff)
    end

    def expand_down
      @end_index += 1
      @lex_diff.concat(@code_lines[@end_index].lex_diff)
    end
  end

  RSpec.describe UpDownExpand do
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
