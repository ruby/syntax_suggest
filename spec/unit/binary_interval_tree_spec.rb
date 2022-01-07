# frozen_string_literal: true

require_relative "../spec_helper"

module DeadEnd
  RSpec.describe BinaryIntervalTree do
    it "works as a binary search tree" do
      tree = Containers::RubyRBTreeMap.new
      tree.push(1, "a")
      tree.push(2, "b")

      expect(tree.get(1)).to be_truthy
      expect(tree.get(9)).to be_falsey
    end

    it "Works as an interval tree" do
      tree = BinaryIntervalTree.new

      tree.push(RangeCmp.new(1..2), "a")
      tree.push(RangeCmp.new(2..2), "b")

      out = tree.search_contains_key(RangeCmp.new(0..3))
      expect(out.count).to eq(2)
      expect(out.map(&:value).sort).to eq(["a", "b"].sort)
    end

    it "only finds ranges it contains" do
      tree = BinaryIntervalTree.new

      tree.push(RangeCmp.new(1..1), "a")
      tree.push(RangeCmp.new(5..5), "not_match")
      tree.push(RangeCmp.new(11..11), "b")

      out = tree.search_contains_key(
        RangeCmp.new(0..3)
      )
      expect(out.count).to eq(1)
      expect(out.map(&:value)).to eq(["a"])

      out = tree.search_contains_key(
        RangeCmp.new(10..12)
      )
      expect(out.count).to eq(1)
      expect(out.map(&:value)).to eq(["b"])
    end

    it "doesn't find deleted nodes" do
      tree = BinaryIntervalTree.new

      tree.push(RangeCmp.new(1..1), "a")
      tree.push(RangeCmp.new(5..5), "not_match")
      tree.push(RangeCmp.new(11..11), "b")

      key = RangeCmp.new(0..3)
      out = tree.search_contains_key(key)
      expect(out.count).to eq(1)
      expect(out.map(&:value)).to eq(["a"])

      out.each { |node| tree.delete(node.key) }

      out = tree.search_contains_key(key)
      expect(out.count).to eq(0)
      expect(out.map(&:value)).to eq([])
    end

    it "lol" do
      tree = BinaryIntervalTree.new
      [
        3..3,
        2..2,
        2..3
      ].each.with_index do |range, i|
        tree.push(RangeCmp.new(range), i)
      end
    end

    it "hahah" do
      tree = BinaryIntervalTree.new
      [
        2..2,
        1..3
      ].each.with_index do |range, i|
        tree.push(RangeCmp.new(range), i)
        end

      out = tree.search_contains_key(RangeCmp.new(1..3))
      expect(out.count).to eq(2)
      tree.delete(RangeCmp.new(2..2))
    end
  end
end
