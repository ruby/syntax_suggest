# frozen_string_literal: true

module DeadEnd

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
        capture_last_end_same_indent(block)
        capture_before_after_kws(block)
        capture_falling_indent(block)
      end

      @lines_to_output.select!(&:not_empty?)
      @lines_to_output.select!(&:not_comment?)
      @lines_to_output.uniq!
      @lines_to_output.sort!

      return @lines_to_output
    end

    def capture_falling_indent(block)
      AroundBlockScan.new(
        block: block,
        code_lines: @code_lines,
      ).on_falling_indent do |line|
        @lines_to_output << line
      end
    end

    def capture_before_after_kws(block)
      around_lines = AroundBlockScan.new(code_lines: @code_lines, block: block)
        .start_at_next_line
        .capture_neighbor_context

      around_lines -= block.lines

      @lines_to_output.concat(around_lines)
    end

    # When there is an invalid with a keyword
    # right before an end, it's unclear where
    # the correct code should be.
    #
    # Take this example:
    #
    #   class Dog       # 1
    #     def bark      # 2
    #       puts "woof" # 3
    #   end             # 4
    #
    # However due to https://github.com/zombocom/dead_end/issues/32
    # the problem line will be identified as:
    #
    #  ❯ class Dog       # 1
    #
    # Because lines 2, 3, and 4 are technically valid code and are expanded
    # first, deemed valid, and hidden. We need to un-hide the matching end
    # line 4. Also work backwards and if there's a mis-matched keyword, show it
    # too
    def capture_last_end_same_indent(block)
      start_index = block.visible_lines.first.index
      lines = @code_lines[start_index..block.lines.last.index]

      # Find first end with same indent
      # (this would return line 4)
      #
      #   end             # 4
      matching_end = lines.select {|line| line.indent == block.current_indent && line.is_end? }.first
      return unless matching_end

      @lines_to_output << matching_end

      lines = @code_lines[start_index..matching_end.index]

      # Work backwards from the end to
      # see if there are mis-matched
      # keyword/end pairs
      #
      # Return the first mis-matched keyword
      # this would find line 2
      #
      #     def bark      # 2
      #       puts "woof" # 3
      #   end             # 4
      end_count = 0
      kw_count = 0
      kw_line = lines.reverse.detect do |line|
        end_count += 1 if line.is_end?
        kw_count += 1 if line.is_kw?

        !kw_count.zero? && kw_count >= end_count
      end
      return unless kw_line
      @lines_to_output << kw_line
    end
  end
end
