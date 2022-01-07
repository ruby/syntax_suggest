# frozen_string_literal: true

require_relative "../spec_helper"

module DeadEnd

  RSpec.describe BinaryIntervalTree do
    it "works manually" do

      tree = BinaryIntervalTree.new()
      tree.insert(1, "a")
      tree.insert(2, "b")

      tree.print

      # tree = BinaryIntervalTree.new(klass: BinaryIntervalTree::RangeNode)
      # tree.insert(1..2, "a")
      # tree.insert(2..2, "b")
    end
  end
end
