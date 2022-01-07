# frozen_string_literal: true

require_relative "../spec_helper"

module DeadEnd

  RSpec.describe BinaryIntervalTree do
    it "works as a binary search tree" do
      tree = BinaryTree.new()
      tree.insert(1, "a")
      tree.insert(2, "b")

      expect(tree.search_key(1)).to be_truthy
      expect(tree.search_key(9)).to be_falsey
    end


    it "Works as an interval tree" do
      tree = BinaryIntervalTree.new

      tree.insert(1..2, "a")
      tree.insert(2..2, "b")


      out = tree.search_contains_key(BinaryTree::RangeCmp.new(0..3))
      expect(out.count).to eq(2)
      expect(out.map(&:data)).to eq(["a", "b"])
    end

    it "only finds ranges it contains" do
      tree = BinaryIntervalTree.new

      tree.insert(1..1, "a")
      tree.insert(5..5, "not_match")
      tree.insert(11..11, "b")

      out = tree.search_contains_key(
        BinaryTree::RangeCmp.new(0..3)
      )
      expect(out.count).to eq(1)
      expect(out.map(&:data)).to eq(["a"])

      out = tree.search_contains_key(
        BinaryTree::RangeCmp.new(10..12)
      )
      expect(out.count).to eq(1)
      expect(out.map(&:data)).to eq(["b"])
    end

    it "doesn't find deleted nodes" do
      tree = BinaryIntervalTree.new

      tree.insert(1..1, "a")
      tree.insert(5..5, "not_match")
      tree.insert(11..11, "b")

      key = BinaryTree::RangeCmp.new(0..3)
      out = tree.search_contains_key(key)
      expect(out.count).to eq(1)
      expect(out.map(&:data)).to eq(["a"])

      out.each {|n| tree.remove_node(n) }

      out = tree.search_contains_key(key)
      expect(out.count).to eq(0)
      expect(out.map(&:data)).to eq([])
    end
  end
end
