# frozen_string_literal: true

module DeadEnd
  # This class is responsible for generating initial code blocks
  # that will then later be expanded.
  #
  # The biggest concern when guessing code blocks, is accidentally
  # grabbing one that contains only an "end". In this example:
  #
  #   def dog
  #     begonn # mispelled `begin`
  #     puts "bark"
  #     end
  #   end
  #
  # The following lines would be matched (from bottom to top):
  #
  #   1) end
  #
  #   2) puts "bark"
  #      end
  #
  #   3) begonn
  #      puts "bark"
  #      end
  #
  # At this point it has no where else to expand, and it will yield this inner
  # code as a block
  #
  # The other major concern is eliminating all lines that do not contain
  # an end. In the above example, if we started from the top and moved
  # down we might accidentally eliminate everything but `end`
  class ParseBlocksFromIndentLine
    attr_reader :code_lines

    def initialize(code_lines:)
      @code_lines = code_lines
    end

    # Builds blocks from bottom up
    def each_neighbor_block(target_line)
      scan = AroundBlockScan.new(code_lines: code_lines, block: CodeBlock.new(lines: target_line))
        .skip(:empty?)
        .skip(:hidden?)
        .scan_while { |line| line.indent >= target_line.indent }

      neighbors = scan.code_block.lines

      # Block production here greatly affects quality and performance.
      #
      # Larger blocks produce a faster search as the frontier must go
      # through fewer iterations. However too large of a block, will
      # degrade output quality if too many unrelated lines are caught
      # in an invalid block.
      #
      # Another concern is being too clever with block production.
      # Quality of the end result depends on sometimes including unrelated
      # lines. For example in code like `deffoo; end` we want to match
      # both lines as the programmer's mistake was missing a space in the
      # `def` even though technically we could make it valid by simply
      # removing the "extra" `end`.
      block = CodeBlock.new(lines: neighbors)
      if neighbors.length <= 2 || block.valid?
        yield block
      else
        until neighbors.empty?
          lines = [neighbors.pop]
          while (block = CodeBlock.new(lines: lines)) && block.invalid? && neighbors.any?
            lines.prepend neighbors.pop
          end

          yield block if block
        end
      end
    end
  end
end
