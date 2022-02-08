# frozen_string_literal: true

require_relative "journey"
require_relative "block_recorder"

module DeadEnd
  # Search for the cause of a syntax error
  #
  # Starts with a BlockNode tree built from IndentTree
  # this has the property of the entire document starting
  # as a single root. From there we inspect the "parents" of
  # the document node to follow the invalid blocks.
  #
  # This process is recorded via one or more `Journey` instances.
  #
  # The search enforces the property that all nodes on a journey
  # would produce a valid document if removed. This holds true
  # from the root node as removing all source code would produce
  # a parsable document
  #
  # After each step in a search, the step is evaluated to see if
  # it preserves the Journey property. If not, it means we've looked
  # too far and have over-shot our syntax error. Or we've made a bad
  # move. In either case we terminate the journey and report its last block.
  #
  # When done, the journey instances can be accessed in the `finished`
  # array
  class IndentSearch
    attr_reader :finished

    def initialize(tree: , record_dir: DEFAULT_VALUE)
      @tree = tree
      @root = tree.root
      @finished = []
      @frontier = [Journey.new(@tree.root)]
      @recorder = BlockRecorder.from_dir(record_dir, subdir: "search", code_lines: tree.code_lines)
    end

    def call
      while (journey = @frontier.pop)
        diagnose = Diagnose.new(journey.node).call
        problem = diagnose.problem
        nodes = diagnose.next

        @recorder.capture(journey.node, name: "pop_#{problem}")

        if nodes.empty? || !holds_all_errors?(nodes)
          @finished << journey
        else
          nodes.each do |block|
            @recorder.capture(block, name: "explore_#{problem}")
            route = journey.deep_dup
            route << Step.new(block)
            @frontier.unshift(route)
          end
        end
      end

      @finished.sort_by! {|j| j.node.starts_at }

      self
    end

    # Check if a given set of blocks holds
    # syntax errors in the context of the document
    #
    # The frontier + finished arrays should always
    # hold all errors for the document.
    #
    # When reducing a node or nodes we need to make sure
    # that while they seem to hold a syntax error in isolation
    # that they also hold it in the full document context.
    #
    # This method accounts for the need to branch/fork a
    # search for multiple syntax errors
    private def holds_all_errors?(blocks)
      blocks = Array(blocks).clone
      blocks.concat(@finished.map(&:node))
      blocks.concat(@frontier.map(&:node))

      without_lines = blocks.flat_map do |block|
        block.lines
      end

      DeadEnd.valid_without?(
        without_lines: without_lines,
        code_lines: @root.lines
      )
    end
  end
end
