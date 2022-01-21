# frozen_string_literal: true

module DeadEnd
  # This class is responsible for taking a code block that exists
  # at a far indentaion and then iteratively increasing the block
  # so that it captures everything within the same indentation block.
  #
  #   def dog
  #     puts "bow"
  #     puts "wow"
  #   end
  #
  # block = BlockExpand.new(code_lines: code_lines)
  #   .call(CodeBlock.new(lines: code_lines[1]))
  #
  # puts block.to_s
  # # => puts "bow"
  #      puts "wow"
  #
  #
  # Once a code block has captured everything at a given indentation level
  # then it will expand to capture surrounding indentation.
  #
  # block = BlockExpand.new(code_lines: code_lines)
  #   .call(block)
  #
  # block.to_s
  # # => def dog
  #        puts "bow"
  #        puts "wow"
  #      end
  #
  class BlockExpand
    def initialize(code_lines:)
      @code_lines = code_lines
    end

    def call(block)
      scan = scan_current_indent(block)

      if scan.captured_current_indent? && scan.line_diff.empty? #.all? {|line| line.empty? || line.hidden? }
        scan.scan_adjacent_indent
      end
      scan.code_block
    end

    def scan_current_indent(block)
      indent = block.current_indent
      scan = AroundBlockScan.new(code_lines: @code_lines, block: block)
        .skip(:hidden?)
        .stop_after_kw

      while !scan.captured_current_indent? && scan.meaningless_capture?
        scan
          .scan_while { |line| line.not_empty? && line.indent >= indent }
          .scan_while { |line| line.empty? } # Slurp up empties
      end
      scan
    end

    # Managable rspec errors
    def inspect
      "#<DeadEnd::CodeBlock:0x0000123843lol >"
    end
  end
end
