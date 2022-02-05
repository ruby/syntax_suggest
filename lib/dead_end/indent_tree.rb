# frozen_string_literal: true

module DeadEnd
  class Recorder
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

    def initialize(tree:)
      @tree = tree
      @root = tree.root
      @finished = []
      @frontier = [Journey.new(@tree.root)]
    end

    def call
      while (journey = @frontier.pop)
        node = journey.node
        case node.diagnose
        when :self
          @finished << journey
          next
        when :fork_invalid
          forks = node.fork_invalid
          if holds_all_errors?(forks)
            forks.each do |block|
              route = journey.deep_dup
              route << Step.new(block)
              @frontier.unshift(route)
            end
          else
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
          journey << Step.new(block)
          @frontier.unshift(journey)
        else
          @finished << journey
          @finished.sort_by! {|j| j.node.starts_at }
          next
        end
      end

      self
    end

    def holds_all_errors?(blocks)
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

    # In isolation a block may appear valid when it isn't or invalid when it is
    # by checking against several levels of the tree, we can have higher
    # confidence that our values are correct
    def holds_all_errors?(blocks)
      @steps.first.valid_without?(blocks)
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

    def valid_without?(blocks)
      without_lines = Array(blocks).flat_map do |block|
        block.lines
      end

      DeadEnd.valid_without?(
        without_lines: without_lines,
        code_lines: @block.lines
      )
    end
  end

  class IndentTree
    attr_reader :document

    def initialize(document:, recorder: DEFAULT_VALUE)
      @document = document
      @last_length = Float::INFINITY

      if recorder != DEFAULT_VALUE
        @recorder = recorder
      else
        dir = ENV["DEAD_END_RECORD_DIR"] || ENV["DEBUG"] ? DeadEnd.record_dir("tmp") : nil
        if dir.nil?
          @recorder = NullRecorder.new
        else
          dir = dir.join("build_tree")
          dir.mkpath
          @recorder = Recorder.new(dir: dir, code_lines: document.code_lines)
        end
      end
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
