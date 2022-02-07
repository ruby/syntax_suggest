# frozen_string_literal: true

module DeadEnd
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
        node = journey.node
        diagnose = node.diagnose
        @recorder.capture(node, name: "pop_#{diagnose}")

        case diagnose
        when :self
          @finished << journey
          next
        when :fork_invalid
          forks = node.fork_invalid
          if holds_all_errors?(forks)

            forks.each do |block|
              @recorder.capture(block, name: "reduced_#{diagnose}")
              route = journey.deep_dup
              route << Step.new(block)
              @frontier.unshift(route)
            end
          else
            forks.each do |block|
              @recorder.capture(block, name: "finished_not_recorded_#{diagnose}")
            end
            @finished << journey
          end

          next
        when :next_invalid
          block = node.next_invalid
        when :split_leaning
          block = node.split_leaning
        when :multiple
          block = node.handle_multiple
        else
          raise "DeadEnd internal error: Unknown diagnosis #{node.diagnose}"
        end


        # When true, we made a good move
        # otherwise, go back to last known reasonable guess
        if holds_all_errors?(block)
          @recorder.capture(block, name: "reduced_#{diagnose}")

          journey << Step.new(block)
          @frontier.unshift(journey)
        else
          @recorder.capture(block, name: "finished_not_recorded_#{diagnose}") if block
          @finished << journey
          next
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
