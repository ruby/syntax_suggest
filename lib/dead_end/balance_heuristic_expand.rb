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
  # This class depends on another class LexPairDiff can be
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
  # Example
  #
  #   lines = CodeLines.from_source(<~'EOM')
  #     if bark?
  #     end
  #   EOM
  #   block = CodeBlock.new(lines: lines[0])
  #
  #   expand = BalanceHeuristicExpand.new(
  #     code_lines: lines,
  #     block: block
  #   )
  #   expand.direction # => :down
  #   expand.call
  #   expand.direction # => :equal
  #
  #   expect(expand.to_s).to eq(lines.join)
  class BalanceHeuristicExpand
    attr_reader :start_index, :end_index

    def initialize(code_lines:, block:)
      @block = block
      @iterations = 0
      @code_lines = code_lines
      @last_index = @code_lines.length - 1
      @max_iterations = @code_lines.length * 2
      @start_index = block.lines.first.index
      @end_index = block.lines.last.index
      @last_equal_range = nil

      set_lex_diff_from(block)
    end

    private def set_lex_diff_from(block)
      @lex_diff = LexPairDiff.new(
        curly: 0,
        square: 0,
        parens: 0,
        kw_end: 0
      )
      block.lines.each do |line|
        @lex_diff.concat(line.lex_diff)
      end
    end

    # Converts the searched lines into a source string
    def to_s
      @code_lines[start_index..end_index].join
    end

    # Converts the searched lines into a code block
    def to_block
      CodeBlock.new(lines: @code_lines[start_index..end_index])
    end

    # Returns true if all lines are equal
    def balanced?
      @lex_diff.balanced?
    end

    # Returns false if captured lines are "leaning"
    # one direction
    def unbalanced?
      !balanced?
    end

    # Main search entrypoint
    #
    # Essentially a state machine, determine the leaning
    # of the given block, then figure out how to either
    # move it towards balanced, or expand it while keeping
    # it balanced.
    def call
      case direction
      when :up
        # the goal is to become balanced
        while keep_going? && direction == :up && try_expand_up
        end
      when :down
        # the goal is to become balanced
        while keep_going? && direction == :down && try_expand_down
        end
      when :equal
        while keep_going? && grab_equal_or {
          # Cannot create a balanced expansion, choose to be unbalanced
          try_expand_up
        }
        end

        call # Recurse
      when :both
        while keep_going? && grab_equal_or {
          try_expand_up
          try_expand_down
        }
        end
      when :stop
        return self
      end

      self
    end

    # Convert a lex diff to a direction to search
    #
    # leaning left -> down
    # leaning right -> up
    #
    def direction
      leaning = @lex_diff.leaning
      case leaning
      when :left # go down
        stop_bottom? ? :stop : :down
      when :right # go up
        stop_top? ? :stop : :up
      when :equal, :both
        if stop_top? && stop_bottom?
          :stop
        elsif stop_top? && !stop_bottom?
          :down
        elsif !stop_top? && stop_bottom?
          :up
        else
          leaning
        end
      end
    end

    # Limit rspec failure output
    def inspect
      "#<DeadEnd::BalanceHeuristicExpand:0x0000000115lol too big>"
    end

    # Upper bound on iterations
    private def keep_going?
      if @iterations < @max_iterations
        @iterations += 1
        true
      else
        warn <<~EOM
          DeadEnd: Internal problem detected, possible infinite loop in #{self.class}

          Please open a ticket with the following information. Max: #{@max_iterations}, actual: #{@iterations}

          Original block:

          ```
          #{@block.lines.map(&:original).join}```

          Stuck at:

          ```
          #{to_block.lines.map(&:original).join}```
        EOM

        false
      end
    end

    # Attempt to grab "free" lines
    #
    # if either above, below or both are
    # balanced, take them, return true.
    #
    # If above is leaning left and below
    # is leaning right and they cancel out
    # take them, return true.
    #
    # If we couldn't grab any balanced lines
    # then call the block and return false.
    private def grab_equal_or
      did_expand = false
      if above&.balanced?
        did_expand = true
        try_expand_up
      end

      if below&.balanced?
        did_expand = true
        try_expand_down
      end

      return true if did_expand

      if make_balanced_from_up_down?
        try_expand_up
        try_expand_down
        true
      else
        yield
        false
      end
    end

    # If up is leaning left and down is leaning right
    # they might cancel out, to make a complete
    # and balanced block
    private def make_balanced_from_up_down?
      return false if above.nil? || below.nil?
      return false if above.lex_diff.leaning != :left
      return false if below.lex_diff.leaning != :right

      @lex_diff.dup.concat(above.lex_diff).concat(below.lex_diff).balanced?
    end

    # The line above the current location
    private def above
      @code_lines[@start_index - 1] unless stop_top?
    end

    # The line below the current location
    private def below
      @code_lines[@end_index + 1] unless stop_bottom?
    end

    # Mutates the start index and applies the new line's
    # lex diff
    private def expand_up
      @start_index -= 1
      @lex_diff.concat(@code_lines[@start_index].lex_diff)
    end

    private def try_expand_up
      stop_top? ? false : expand_up
    end

    private def try_expand_down
      stop_bottom? ? false : expand_down
    end

    # Mutates the end index and applies the new line's
    # lex diff
    private def expand_down
      @end_index += 1
      @lex_diff.concat(@code_lines[@end_index].lex_diff)
    end

    # Returns true when we can no longer expand up
    private def stop_top?
      @start_index == 0
    end

    # Returns true when we can no longer expand down
    private def stop_bottom?
      @end_index == @last_index
    end
  end
end
