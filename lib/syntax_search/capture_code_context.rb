# frozen_string_literal: true

module SyntaxErrorSearch

  # Given a block, this method will capture surrounding
  # code to give the user more context for the location of
  # the problem.
  #
  # Return is an array of CodeLines to be rendered.
  #
  # Surrounding code is captured regardless of visible state
  #
  #   puts block.to_s # => "def bark"
  #
  #   context = CaptureCodeContext.new(
  #     blocks: block,
  #     code_lines: code_lines
  #   )
  #
  #   puts context.call.join
  #   # =>
  #     class Dog
  #       def bark
  #     end
  #
  class CaptureCodeContext
    attr_reader :code_lines

    def initialize(blocks: , code_lines:)
      @blocks = Array(blocks)
      @code_lines = code_lines
      @visible_lines = @blocks.map(&:visible_lines).flatten
      @lines_to_output = @visible_lines.dup
    end

    def call
      @blocks.each do |block|
        around_lines = AroundBlockScan.new(code_lines: @code_lines, block: block)
          .stop_after_kw
          .scan_while {|line| line.empty? || line.indent >= block.current_indent }
          .code_block
          .lines
          .select {|l| l.indent == block.current_indent && ! block.lines.include?(l) }

        @lines_to_output.concat(around_lines)

        AroundBlockScan.new(
          block: block,
          code_lines: @code_lines,
        ).on_falling_indent do |line|
          @lines_to_output << line
        end
      end

      return @lines_to_output.uniq.select(&:not_empty?).sort
    end
  end
end
