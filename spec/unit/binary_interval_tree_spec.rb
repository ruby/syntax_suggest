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

    it "uses annotations to find nodes stored in reverse range" do
      tree = BinaryIntervalTree.new

      tree.push(RangeCmpRev.new(1..1), "a")
      tree.push(RangeCmpRev.new(5..5), "not_match")
      tree.push(RangeCmpRev.new(11..11), "b")

      out = tree.search_contains_key(
        RangeCmpRev.new(0..3)
      )
      expect(out.count).to eq(1)
      expect(out.map(&:value)).to eq(["a"])

      out = tree.search_contains_key(
        RangeCmpRev.new(10..12)
      )
      expect(out.count).to eq(1)
      expect(out.map(&:value)).to eq(["b"])
    end

    it "uses annotations to improve search" do
      tree = BinaryIntervalTree::Debug.new
      [
        20..36, # 0
        29..99, # 1
        3..41, # 2
        0..1, # 3
        10..15 # 4
      ].each.with_index do |range, i|
        tree.push(RangeCmp.new(range), i)
      end

      out = tree.search_overlap(
        RangeCmp.new(20..36)
      )
      expect(out.map(&:value)).to eq([0])

      out = tree.search_overlap(
        RangeCmp.new(29..99)
      )
      expect(out.map(&:value)).to eq([1])

      out = tree.search_overlap(
        RangeCmp.new(3..41)
      )
      expect(out.map(&:value)).to eq([0, 2, 4])

      out = tree.search_overlap(
        RangeCmp.new(0..1)
      )
      expect(out.map(&:value)).to eq([3])

      out = tree.search_overlap(
        RangeCmp.new(10..15)
      )
      expect(out.map(&:value)).to eq([4])

      # tree = BinaryIntervalTree::Debug.new
      # [
      #   20..36,
      #   29..99,
      #   3..41,
      #   0..1,
      #   10..15
      # ].each.with_index do |range, i|
      #   tree.push(RangeCmpRev.new(range), i)
      # end

      # skip("Work on reverse later")

      # out = tree.search_contains_key(
      #   RangeCmpRev.new(20..36)
      # )
      # expect(out.map(&:value)).to eq([0])

      # out = tree.search_contains_key(
      #   RangeCmpRev.new(29..99)
      # )
      # expect(out.map(&:value)).to eq([1])

      # out = tree.search_contains_key(
      #   RangeCmpRev.new(3..41)
      # )
      # expect(out.map(&:value)).to eq([0, 2, 4])

      # out = tree.search_contains_key(
      #   RangeCmpRev.new(0..1)
      # )
      # expect(out.map(&:value)).to eq([3])

      # out = tree.search_contains_key(
      #   RangeCmpRev.new(10..15)
      # )
      # expect(out.map(&:value)).to eq([4])

      # puts "rev"
      # puts tree.count
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

    it "annotations" do
      # Build a print function
      # print before and after rotation
      # https://tildesites.bowdoin.edu/~ltoma/teaching/cs231/fall09/Lectures/10-augmentedTrees/augtrees.pdf
      # page 6

      tree = BinaryIntervalTree::Debug.new

      i = 0
      tree.push(RangeCmp.new(29..99), i += 1)
      tree.push(RangeCmp.new(10..15), i += 1)
      tree.push(RangeCmp.new(3..41), i += 1)
      tree.push(RangeCmp.new(20..36), i += 1)
      tree.push(RangeCmp.new(0..1), i += 1)

      out = tree.get_node_for_key(
        RangeCmp.new(29..99)
      )
      expect(out.annotate).to eq(99)

      out = tree.get_node_for_key(
        RangeCmp.new(20..36)
      )
      expect(out.annotate).to eq(36)

      out = tree.get_node_for_key(
        RangeCmp.new(3..41)
      )
      expect(out.annotate).to eq(41)

      out = tree.get_node_for_key(
        RangeCmp.new(0..1)
      )
      expect(out.annotate).to eq(1)

      out = tree.get_node_for_key(
        RangeCmp.new(10..15)
      )
      expect(out.annotate).to eq(99)
    end

    # it "reverse annotations" do
    #   skip
    #   tree = BinaryIntervalTree.new
    #   [
    #     20..36,
    #     29..99,
    #     3..41,
    #     0..1,
    #     10..15
    #   ].each.with_index do |range, i|
    #     tree.push(RangeCmpRev.new(range), i)
    #   end

    #   out = tree.get_node_for_key(
    #     RangeCmpRev.new(29..99)
    #   )
    #   expect(out.annotate).to eq(29)

    #   out = tree.get_node_for_key(
    #     RangeCmpRev.new(3..41)
    #   )
    #   expect(out.annotate).to eq(29)

    #   # out = tree.get_node_for_key(
    #   #   RangeCmpRev.new(0..1)
    #   # )
    #   # expect(out.annotate).to eq(0)

    #   # out = tree.get_node_for_key(
    #   #   RangeCmpRev.new(20..36)
    #   # )
    #   # expect(out.annotate).to eq(20)

    #   out = tree.get_node_for_key(
    #     RangeCmpRev.new(10..15)
    #   )
    #   expect(out.annotate).to eq(20)
    # end
  end
end
