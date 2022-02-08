# frozen_string_literal: true

module DeadEnd
  # A core data structure
  #
  # A block node keeps a reference to the block above it
  # and below it. In addition a block can "capture" another
  # block. Block nodes are treated as immutable(ish) so when that happens
  # a new node is created that contains a refernce to all the blocks it was
  # derived from. These are known as a block's "parents".
  #
  # If you walk the parent chain until it ends you'll end up with nodes
  # representing individual lines of code (generated from a CodeLine).
  #
  # An important concept in a block is that it knows how it is "leaning"
  # based on it's internal LexPairDiff. If it's leaning `:left` that means
  # it needs to capture something to it's right/down to be balanced again.
  #
  # Note: that that the capture method is on BlockDocument since it needs to
  # retain a valid reference to it's root.
  #
  # Another important concept is that blocks know their current indentation
  # as well as can accurately derive their "next" indentation for when/if
  # they're expanded. To be calculated a nodes above and below blocks must
  # be accurately assigned. So this property cannot be calculated at creation
  # time.
  #
  # Beyond these core capabilities blocks also know how to `diagnose` what
  # is wrong with them. And then they can take an action based on that
  # diagnosis. For example `node.diagnose == :split_leaning` indicates that
  # it contains parents invalid parents that likey represent an invalid node
  # sandwitched between a left and right leaning node. This will happen with
  # code. For example `[`, `bad &*$@&^ code`, `]`. Then the inside invalid node
  # can be grabbed via calling `node.split_leaning`.
  #
  # In the long term it likely makes sense to move diagnosis and extraction
  # to a separate class as this class already is a bit of a "false god object"
  # however a lot of tests depend on it currently and it's not really getting
  # in the way.
  class BlockNode
    # Helper to create a block from other blocks
    #
    #   parents = node.parents
    #   expect(parents[0].leaning).to eq(:left)
    #   expect(parents[2].leaning).to eq(:right)
    #
    #   block = BlockNode.from_blocks([parents[0], parents[2]])
    #   expect(block.leaning).to eq(:equal)
    def self.from_blocks(parents)
      lines = []
      parents = parents.first.parents if parents.length == 1 && parents.first.parents.any?
      indent = parents.first.indent
      lex_diff = LexPairDiff.new_empty
      parents.each do |block|
        lines.concat(block.lines)
        lex_diff.concat(block.lex_diff)
        indent = block.indent if block.indent < indent
        block.delete
      end

      node = BlockNode.new(
        lines: lines,
        lex_diff: lex_diff,
        indent: indent,
        parents: parents
      )

      node.above = parents.first.above
      node.below = parents.last.below
      node
    end

    attr_accessor :above, :below, :left, :right, :parents
    attr_reader :lines, :start_index, :end_index, :lex_diff, :indent, :starts_at, :ends_at

    def initialize(lines:, indent:, next_indent: nil, lex_diff: nil, parents: [])
      lines = Array(lines)
      @indent = indent
      @next_indent = next_indent
      @lines = lines
      @parents = parents

      @start_index = lines.first.index
      @end_index = lines.last.index

      @starts_at = @start_index + 1
      @ends_at = @end_index + 1

      if lex_diff.nil?
        set_lex_diff_from(@lines)
      else
        @lex_diff = lex_diff
      end

      @deleted = false
    end

    # Used to determine when to expand up in building
    # a tree. Also used to calculate the `next_indent`.
    #
    # There is a tight coupling between the two concepts
    # as the `next_indent` is used to determine node expansion
    # priority
    def expand_above?(with_indent: indent)
      return false if above.nil?
      return false if leaf? && leaning == :left

      if above.leaning == :left
        above.indent >= with_indent
      else
        true
      end
    end

    # Used to determine when to expand down in building
    # a tree. Also used to calculate the `next_indent`.
    #
    # There is a tight coupling between the two concepts
    # as the `next_indent` is used to determine node expansion
    # priority
    def expand_below?(with_indent: indent)
      return false if below.nil?
      return false if leaf? && leaning == :right

      if below.leaning == :right
        below.indent >= with_indent
      else
        true
      end
    end

    def leaf?
      parents.empty?
    end

    # When diagnose is `:next_invalid` it indicates that
    # only one parent is not valid. Therefore we must
    # follow that node if we wish to continue reducing
    # the invalid blocks
    def next_invalid
      parents.detect(&:invalid?)
    end

    # Returns a symbol correlated to the current node's
    # parents state
    #
    # - :self - Leaf node, problem must be with self
    # - :next_invalid - Only one invalid parent node found
    # - :split_leaning - Invalid block is sandwiched between
    #   a left/right leaning block, grab the inside
    # - :multiple - multiple parent blocks are detected as being
    #   invalid but it's not a "split leaning". If we can reduce/remove
    #   one or more of these blocks by pairing with the above/below
    #   nodes then we can reduce multiple invalid blocks to possibly
    #   be a single invalid block.
    # - :fork_invalid - If we got here, it looks like there's actually
    #   multiple syntax errors in multiple parents.
    def diagnose
      return :self if leaf?

      invalid = parents.select(&:invalid?)
      return :next_invalid if invalid.count == 1

      return :split_leaning if split_leaning?

      return :multiple if reduce_multiple?

      :fork_invalid
    end

    # - :fork_invalid - If we got here, it looks like there's actually
    #   multiple syntax errors in multiple parents.
    def fork_invalid
      parents.select(&:invalid?).map do |block|
        BlockNode.from_blocks([block])
      end
    end

    # - :multiple - multiple parent blocks are detected as being
    #   invalid but it's not a "split leaning". If we can reduce/remove
    #   one or more of these blocks by pairing with the above/below
    #   nodes then we can reduce multiple invalid blocks to possibly
    #   be a single invalid block.
    #
    # - valid rescue/else
    # - leaves inside of an array/hash
    def handle_multiple
      if reduced_multiple_invalid_array.any?
        @reduce_multiple ||= BlockNode.from_blocks(reduced_multiple_invalid_array)
      end
    end
    alias :reduce_multiple :handle_multiple

    private def reduced_multiple_invalid_array
      @reduced_multiple_invalid_array ||= begin
        invalid = parents.select(&:invalid?)
        # valid rescue/else
        if above && above.leaning == :left && below && below.leaning == :right
          before_length = invalid.length
          invalid.reject! { |block|
            b = BlockNode.from_blocks([above, block, below])
            b.leaning == :equal && b.valid?
          }
          if invalid.any? && invalid.length != before_length
            invalid
          else
            []
          end
          # return BlockNode.from_blocks(invalid) if invalid.any? && invalid.length != before_length
        else
          []
        end
      end
    end

    def reduce_multiple?
      reduced_multiple_invalid_array.any?
    end

    # In isolation left and right leaning blocks
    # are invalid. For example `(` and `)`.
    #
    # If we see 3 or more invalid blocks and the outer
    # are leaning left and right, then the problem might
    # be between the leaning blocks rather than with them
    def split_leaning
      block = left_right_parents
      invalid = parents.select(&:invalid?)

      invalid.reject! { |x| block.parents.include?(x) }

      @inner_leaning ||= BlockNode.from_blocks(invalid)
    end

    private def left_right_parents
      invalid = parents.select(&:invalid?)
      return false if invalid.length < 3

      left = invalid.detect { |block| block.leaning == :left }

      return false if left.nil?

      right = invalid.reverse_each.detect { |block| block.leaning == :right }
      return false if right.nil?

      @left_right_parents ||= BlockNode.from_blocks([left, right])
    end

    # When a kw/end has an invalid block inbetween it will show up as [false, false, false]
    # we can check if the first and last can be joined together for a valid block which
    # effectively gives us [true, false, true]
    def split_leaning?
      block = left_right_parents
      if block
        block.leaning == :equal && block.valid?
      else
        false
      end
    end

    # Given a node, it's above and below links
    # returns the next indentation.
    #
    # The algorithm for the logic follows:
    #
    # Expand given the current rules and current indentation
    # keep doing that until we can't anymore. When we can't
    # then pick the lowest indentation that will capture above
    # and below blocks.
    #
    # The results of this algorithm are tightly coupled to
    # tree building and therefore search.
    def self.next_indent(above, node, below)
      return node.indent if node.expand_above? || node.expand_below?

      if above
        if below
          case above.indent <=> below.indent
          when 1 then below.indent
          when 0 then above.indent
          when -1 then above.indent
          end
        else
          above.indent
        end
      elsif below
        below.indent
      else
        node.indent
      end
    end

    # Calculating the next_indent must be done after above and below
    # have been assigned (otherwise we would have a race condition).
    def next_indent
      @next_indent ||= self.class.next_indent(above, self, below)
    end

    # It's useful to be able to mark a node as deleted without having
    # to iterate over a data structure to remove it.
    #
    # By storing a deleted state of a node we can instead lazilly ignore it
    # as needed. This is a performance optimization.
    def delete
      @deleted = true
    end

    def deleted?
      @deleted
    end

    # Code within a given node is not syntatically valid
    def invalid?
      !valid?
    end

    # Code within a given node is syntatically valid
    #
    # Value is memoized for performance
    def valid?
      return @valid if defined?(@valid)

      @valid = DeadEnd.valid?(@lines.join)
    end

    # Opposite of `balanced?`
    def unbalanced?
      !balanced?
    end

    # A node that is `leaning == :equal` is determined to be "balanced".
    #
    # Alternative states include :left, :right, or :both
    def balanced?
      @lex_diff.balanced?
    end

    # Returns the direction a block is leaning
    #
    # States include :equal, :left, :right, and :both
    def leaning
      @lex_diff.leaning
    end

    def to_s
      @lines.join
    end

    # Determines priority of node within a priority data structure
    # (such as a priority queue).
    #
    # This is tightly coupled to tree building and search.
    #
    # It's also a performance sensitive area. An optimization
    # not yet taken would be to re-encode the same data as a string
    # so a node with next indent of 8, current indent of 10 and line
    # of 100 might possibly be encoded as `008001000100` which would
    # sort the same as this logic. Preliminary benchmarks indicate a
    # rough 2x speedup
    def <=>(other)
      case next_indent <=> other.next_indent
      when 1 then 1
      when -1 then -1
      when 0
        case indent <=> other.indent
        when 1 then 1
        when -1 then -1
        when 0

          end_index <=> other.end_index
        end
      end
    end

    # Provide meaningful diffs in rspec
    def inspect
      "#<DeadEnd::BlockNode 0x000000010cbfelol range=#{@start_index}..#{@end_index}, @indent=#{indent}, @next_indent=#{next_indent}, @parents=#{@parents.inspect}>"
    end

    # Generate a new lex pair diff given an array of lines
    private def set_lex_diff_from(lines)
      @lex_diff = LexPairDiff.new_empty
      lines.each do |line|
        @lex_diff.concat(line.lex_diff)
      end
    end

    # Needed for meaningful rspec assertions
    def ==(other)
      @lines == other.lines && @indent == other.indent && next_indent == other.next_indent && @parents == other.parents
    end
  end
end
