# frozen_string_literal: true

module DeadEnd
  # Each journey represents a walk of the graph to eliminate
  # invalid code
  #
  # We can check the a step's validity by asserting that it's removal produces
  # valid code from it's parent
  #
  #  node = tree.root
  #  journey = Journey.new(node)
  #  journey << Step.new(node.parents[0])
  #  expect(journey.node).to eq(node.parents[0])
  #
  class Journey
    attr_reader :steps

    def initialize(root)
      @root = root
      @steps = [Step.new(root)]
    end

    # Needed so we don't internally mutate the @steps array
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
end
