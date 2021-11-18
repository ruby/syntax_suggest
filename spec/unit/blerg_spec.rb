# frozen_string_literal: true

require_relative "../spec_helper"

module DeadEnd

  class CodePartitionByKw
    attr_reader :invalid_blocks

    def initialize(code_lines: )
      @code_lines = code_lines
      @invalid_blocks = []
      @last_line_number = @code_lines.last.line_number
    end

    def call
      sections = []
      until sections.last&.ends_at == @last_line_number
        start = sections.last&.ends_at || 0
        sections << scan_for_kw_end(start: start)
      end

      sections.each do |block|
        @invalid_blocks << block if block.invalid?
      end
      self
    end

    private def scan_for_kw_end(start: )
      kw_count = 0
      end_count = 0
      stop_next = false
      lines = @code_lines[start..-1].take_while do |line|
        next false if stop_next
        kw_count += 1 if line.is_kw?
        end_count += 1 if line.is_end?
        if end_count >= kw_count
          stop_next = true
        end

        true
      end

      CodeBlock.new(lines: lines)
    end
  end

  class CodeBinarySearch
    attr_reader :invalid_blocks

    def initialize(code_lines: )
      @code_lines = code_lines
      @invalid_blocks = []
    end

    def call
      frontier = CodePartitionByKw.new(
        code_lines: @code_lines
      ).call.invalid_blocks

      while block = frontier.pop
        puts "====================================="
        puts DisplayCodeWithLineNumbers.new(
          lines: block.lines
        ).call

        indent = block.current_indent
        next_lines = block.lines.select { |line| line.indent > indent || line.empty? }
        if DeadEnd.valid_without?(code_lines: block.lines, without_lines: next_lines)
          CodePartitionByKw.new(
            code_lines: next_lines
          ).call.invalid_blocks.each do |block|
            frontier << block
          end
        else
          @invalid_blocks << block
        end

        self
      end
    end
  end

  RSpec.describe CodePartitionByKw do
    it "splits source code in half" do
      source = <<~'EOM'
        class Foo
        end
        class Bar
          def lol
        end
      EOM

      obj =  CodePartitionByKw.new(code_lines: CodeLine.from_source(source))
      obj.call

      expect(obj.invalid_blocks.join).to match(<<~'EOM')
        class Bar
          def lol
        end
      EOM
    end

    it "splits out" do
      source = <<~'EOM'
        class Foo
          class Bar
            def lol
          end
          class Baz
          end
        end
      EOM

      obj =  CodeBinarySearch.new(code_lines: CodeLine.from_source(source))
      obj.call

      expect(obj.invalid_blocks.join).to match(<<~'EOM')
          def lol
      EOM
    end

    # Problem: Flat, long files take too long to search outside in
    # Solution: Split them in half based on keywords

    # Done
    ## Bigger problem: The i
    it "lol" do
      file = fixtures_dir.join("syntax_tree.rb.txt")
      lines = file.read.lines
      lines.delete_at(768 - 1)

      code_lines = CodeLine.from_source(lines.join)
      obj =  CodeBinarySearch.new(code_lines: code_lines)
      obj.call


      puts DisplayCodeWithLineNumbers.new(
        lines: obj.invalid_blocks.map(&:lines).flatten
      ).call

      # expect(obj.invalid_blocks.join).to match(<<~'EOM')
      #     def lol
      # EOM
    end

  end
end
