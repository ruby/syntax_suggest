# frozen_string_literal: true

module DeadEnd
  class BlockRecorder
    def self.from_dir(dir, subdir: , code_lines: )
      if dir == DEFAULT_VALUE
        dir = ENV["DEAD_END_RECORD_DIR"] || ENV["DEBUG"] ? DeadEnd.record_dir("tmp") : nil
      end

      if dir.nil?
        NullRecorder.new
      else
        dir = Pathname(dir)
        dir = dir.join(subdir)
        dir.mkpath
        BlockRecorder.new(dir: dir, code_lines: code_lines)
      end
    end

    def initialize(dir:, code_lines:)
      @code_lines = code_lines
      @dir = Pathname(dir)
      @tick = 0
      @name_tick = Hash.new { |h, k| h[k] = 0 }
    end

    def capture(block, name:)
      @tick += 1

      filename = "#{@tick}-#{name}-#{@name_tick[name] += 1}-(#{block.starts_at}__#{block.ends_at}).txt"
      @dir.join(filename).open(mode: "a") do |f|
        document = DisplayCodeWithLineNumbers.new(
          lines: @code_lines,
          terminal: false,
          highlight_lines: block.lines
        ).call

        f.write("    Block lines: #{(block.starts_at + 1)..(block.ends_at + 1)} (#{name})\n")
        f.write("    indent: #{block.indent} next_indent: #{block.next_indent}\n\n")
        f.write(document.to_s)
      end
    end
  end

  class NullRecorder
    def capture(block, name:)
    end
  end

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

  # Each journey represents a walk of the graph to eliminate
  # invalid code
  #
  # We can check the a step's validity by asserting that it's removal produces
  # valid code from it's parent
  class Journey
    attr_reader :steps

    def initialize(root)
      @root = root
      @steps = [Step.new(root)]
    end

    def deep_dup
      j = Journey.new(@root)
      steps.each do |step|
        j << step
      end
      j
    end

    def to_s
      node.to_s
    end

    def <<(step)
      @steps << step
    end

    def node
      @steps.last.block
    end
  end

  class Step
    attr_reader :block

    def initialize(block)
      @block = block
    end

    def to_s
      block.to_s
    end
  end

  class IndentTree
    attr_reader :document, :code_lines

    def initialize(document:, record_dir: DEFAULT_VALUE)
      @document = document
      @code_lines = document.code_lines
      @last_length = Float::INFINITY


      @recorder = BlockRecorder.from_dir(record_dir, subdir: "build_tree", code_lines: @code_lines)
    end

    def to_a
      @document.to_a
    end

    def root
      @document.root
    end

    def call
      reduce

      self
    end

    private def reduce
      while (block = document.pop)
        original = block
        blocks = [block]

        indent = original.next_indent

        while blocks.last.expand_above?(with_indent: indent)
          above = blocks.last.above
          leaning = above.leaning
          # break if leaning == :right
          blocks << above
          break if leaning == :left
        end

        blocks.reverse!

        while blocks.last.expand_below?(with_indent: indent)
          below = blocks.last.below
          leaning = below.leaning
          # break if leaning == :left
          blocks << below
          break if leaning == :right
        end

        @recorder.capture(original, name: "pop")

        if blocks.length > 1
          node = document.capture_all(blocks)
          @recorder.capture(node, name: "expand")
          document.queue << node
        end
      end
      self
    end

    def to_s
      @document.to_s
    end
  end
end
