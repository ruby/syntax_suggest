# frozen_string_literal: true

module DeadEnd
  # Expand code based on lexical heuristic
  #
  # Code that has unbalanced pairs cannot be valid
  # i.e. `{` must always be matched with a `}`.
  #
  # This expansion class exploits that knowledge to
  # expand a logical block towards equal pairs.
  #
  # For example: if code is missing a `]` it cannot
  # be on a line above, so it must expand down
  #
  # This heuristic allows us to make larger and more
  # accurate expansions which means fewer invalid
  # blocks to check which means overall faster search.
  #
  # This class depends on another class LexDiff can be
  # accesssed per-line. It holds the delta of tracked directional
  # pairs: curly brackets, square brackets, parens, and kw/end
  # with positive count (leaning left), 0 (balanced), or negative
  # count (leaning right).
  #
  # With this lexical diff information we can look around a given
  # block and move with inteligently. For instance if the current
  # block has a miss matched `end` and the line above it holds
  # `def foo` then the block will be expanded up to capture that line.
  #
  # An unbalanced block can never be valid (this provides info to
  # the overall search). However a balanced block may contain other syntax
  # error and so must be re-checked using Ripper (slow).
  #
  #
  class UpDownExpand
    attr_reader :start_index, :end_index

    def initialize(code_lines: , block: )
      @code_lines = code_lines
      @last_index = @code_lines.length - 1
      @block = block

      @lex_diff = nil
      block.lines.each do |line|
        if @lex_diff.nil?
          @lex_diff = LexDiff.new(
            curly: line.lex_diff.curly,
            square: line.lex_diff.square,
            parens: line.lex_diff.parens,
            kw_end: line.lex_diff.kw_end,
          )
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

    def to_block
      CodeBlock.new(lines: @code_lines[start_index..end_index])
    end

    def balanced?
      @lex_diff.balanced?
    end

    def unbalanced?
      !balanced?
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
      when :unknown
        while grab_equal_or {
          expand_up unless stop_top?
          expand_down unless stop_bottom?
        }
        end
      when :stop
        return self
      end

      self
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


    private def grab_equal_or
      did_expand = false
      if above&.balanced?
        did_expand = true
        expand_up
      end

      if below&.balanced?
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

    private def above
      @code_lines[@start_index - 1] unless stop_top?
    end

    private def below
      @code_lines[@end_index + 1] unless stop_bottom?
    end

    private def expand_up
      @start_index -= 1
      @lex_diff.concat(@code_lines[@start_index].lex_diff)
    end

    private def expand_down
      @end_index += 1
      @lex_diff.concat(@code_lines[@end_index].lex_diff)
    end

    private def stop_top?
      @start_index == 0
    end

    private def stop_bottom?
      @end_index == @last_index
    end

  end

end
