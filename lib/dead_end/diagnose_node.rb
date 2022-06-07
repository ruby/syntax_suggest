# frozen_string_literal: true

module DeadEnd
  # Explore and diagnose problems with a block
  #
  # Given an invalid node, the root cause of the syntax error
  # may exist in that node, or in one or more of it's parents.
  #
  # The DiagnoseNode class is responsible for determining the most reasonable next move to
  # make.
  #
  # Results can be best effort, i.e. they must be re-checked against a document
  # before being recommended to a user. We still want to take care in making the
  # best possible suggestion as a bad suggestion may halt the search at a suboptimal
  # location.
  #
  # The algorithm here is tightly coupled to the nodes produced by the current IndentTree
  # implementation.
  #
  # Possible problem states:
  #
  # - :self - The block holds no parents, if it holds a problem its in the current node.
  #
  # - :invalid_inside_split_pair - An invalid block is splitting two valid leaning blocks, return the middle.
  #
  # - :remove_pseudo_pair - Multiple invalid blocks in isolation are present, but when paired with external leaning
  #   blocks above and below they become valid. Remove these and group the leftovers together. i.e. don't
  #   scapegoat `else/ensure/rescue`, remove them from the block and retry with whats leftover.
  #
  # - :extract_from_multiple - Multiple invalid blocks in isolation are present, but we were able to find one that could be removed
  #   to make a valid set along with outer leaning i.e. `[`, `in)&lid` , `vaild`, `]`. Different from :invalid_inside_split_pair because
  #   the leaning elements come from different blocks above & below. At the end of a journey split_leaning might break one invalid
  #   node into multiple parents that then hit :extract_from_multiple
  #
  # - :one_invalid_parent - Only one parent is invalid, better investigate.
  #
  # - :multiple_invalid_parents - Multiple blocks are invalid, they cannot be reduced or extracted, we will have to fork the search and
  #   explore all of them independently.
  #
  # Returns the next 0, 1 or N node(s) based on the given problem state.
  #
  # - 0 nodes returned by :self
  # - 1 node returned by :invalid_inside_split_pair, :remove_pseudo_pair, :extract_from_multiple, :one_invalid_parent
  # - N nodes returned by :multiple_invalid_parents
  #
  # Usage example:
  #
  #   diagnose = DiagnoseNode.new(block).call
  #   expect(diagnose.problem).to eq(:multiple_invalid_parents)
  #   expect(diagnose.next.length).to eq(2)
  #
  class DiagnoseNode
    attr_reader :block, :problem, :next

    def initialize(block)
      @block = block
      @problem = nil
      @next = []
    end

    def call
      invalid = get_invalid
      return self if invalid.empty?

      @next = if @problem == :multiple_invalid_parents
        invalid.map { |b| BlockNode.from_blocks([b]) }
      else
        invalid
      end

      self
    end

    # Checks for the common problem states a node might face.
    # returns an array of 0, 1 or N blocks
    private def get_invalid
      out = diagnose_self
      return out if out

      out = diagnose_left_right
      return out if out

      out = diagnose_above_below
      return out if out

      diagnose_one_or_more_parents
    end

    # Diagnose left/right
    #
    # Handles cases where the block is made up of a several nodes and is book ended by
    # nodes leaning in the correct direction that pair with one another. For example [`{`, `b@&[d`, `}`]
    #
    # This is different from above/below which also has matching blocks, but those are outside of the current
    # block array (they are above and below it respectively)
    #
    # ## (:invalid_inside_split_pair) Handle case where keyword/end (or any pair) is falsely reported as invalid in isolation but
    # holds a syntax error inside of it.
    #
    # Example:
    #
    # ```
    # def cow        # left, invalid in isolation, valid when paired with end
    #   inv&li) code # Actual problem to be isolated
    # end            # right, invalid in isolation, valid when paired with def
    # ```
    private def diagnose_left_right
      invalid = block.parents.select(&:invalid?)
      return false if invalid.length < 3

      left = invalid.detect { |block| block.leaning == :left }
      right = invalid.reverse_each.detect { |block| block.leaning == :right }

      if left && right && BlockNode.from_blocks([left, right]).valid?
        @problem = :invalid_inside_split_pair

        invalid.reject! { |b| b == left || b == right }

        # If the left/right was not mapped properly or we've accidentally got a :multiple_invalid_parents
        # we can get a false positive, double check the invalid lines fully capture the problem
        if DeadEnd.valid_without?(
          code_lines: block.lines,
          without_lines: invalid.flat_map(&:lines)
        )

          invalid
        end
      end
    end

    # ## (:remove_pseudo_pair) Handle else/ensure case
    #
    # Example:
    #
    # ```
    # def cow         # above
    #   print inv&li) # Actual problem
    # rescue => e     # Invalid in isolation, valid when paired with above/below
    # end             # below
    # ```
    #
    # ## (:extract_from_multiple) Handle syntax seems fine in isolation, but not when combined with above/below leaning blocks
    #
    # Example:
    #
    # ```
    # [ # above
    #    missing_comma_not_okay
    #    missing_comma_okay
    # ] # below
    # ```
    #
    private def diagnose_above_below
      invalid = block.parents.select(&:invalid?)

      above = block.above if block.above&.leaning == :left
      below = block.below if block.below&.leaning == :right
      return false if above.nil? || below.nil?

      if invalid.reject! { |block|
           b = BlockNode.from_blocks([above, block, below])
           b.leaning == :equal && b.valid?
         }

        if invalid.any?
          # At this point invalid array was reduced and represents only
          # nodes that are invalid when paired with it's above/below
          # however, we may need to split the node apart again
          @problem = :remove_pseudo_pair

          [BlockNode.from_blocks(invalid, above: above, below: below)]
        else
          invalid = block.parents.select(&:invalid?)

          # If we can remove one node from many blocks to make the other blocks valid then, that
          # block must be the problem
          if (b = invalid.detect { |b| BlockNode.from_blocks([above, invalid - [b], below].flatten).valid? })
            @problem = :extract_from_multiple
            [b]
          end
        end
      end
    end

    # We couldn't detect any special cases, either return 1 or N invalid nodes
    private def diagnose_one_or_more_parents
      invalid = block.parents.select(&:invalid?)
      if invalid.length > 1
        if (b = invalid.detect { |b| BlockNode.from_blocks([invalid - [b]].flatten).valid? })
          @problem = :extract_from_multiple
          [b]
        else
          @problem = :multiple_invalid_parents
          invalid
        end
      else
        @problem = :one_invalid_parent
        invalid
      end
    end

    private def diagnose_self
      if block.parents.empty?
        @problem = :self
        []
      end
    end
  end
end
