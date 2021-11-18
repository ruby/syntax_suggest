# frozen_string_literal: true

require_relative "../spec_helper"

module DeadEnd

  class FakeBlockForTree
    attr_reader :indent, :length, :to_s, :range_index

    def initialize(indent: ,length: , to_s: , range_index: 0..0)
      @length = length
      @indent = indent
      @to_s = to_s
      @range_index = range_index
    end
  end

  RSpec.describe BlockIndentTree do
    it "bsearch" do
      tree = BlockIndentTree.new
      tree << FakeBlockForTree.new(indent: 0, length: 1, to_s: "valid")
      tree << FakeBlockForTree.new(indent: 0, length: 3, to_s: "invalid")
      tree << FakeBlockForTree.new(indent: 0, length: 5, to_s: "invalid")
      tree.finalize

      expect(tree.bsearch {|largest| largest.to_s == "invalid" }.block ).to eq(tree.at_indent(0)[1])
      expect(tree.bsearch {|largest| largest.to_s == "invalid" }.parent).to eq(tree.at_indent(0)[0])
    end

    it "bsearch_index gives the largest_block that matches" do
      tree = BlockIndentTree.new
      tree << FakeBlockForTree.new(indent: 0, length: 1, to_s: "valid")
      tree << FakeBlockForTree.new(indent: 0, length: 3, to_s: "invalid")
      tree << FakeBlockForTree.new(indent: 0, length: 5, to_s: "invalid")
      tree.finalize

      expect(tree.bsearch_index(indent: 0) {|largest| largest.to_s == "invalid" } ).to eq(1)
    end

    it "bsearch_indent gives the higest indent level that matches" do
      tree = BlockIndentTree.new
      tree << FakeBlockForTree.new(indent: 3, length: 1, to_s: "valid")
      tree << FakeBlockForTree.new(indent: 2, length: 1, to_s: "valid")
      tree << FakeBlockForTree.new(indent: 1, length: 1, to_s: "invalid")
      tree << FakeBlockForTree.new(indent: 0, length: 5, to_s: "invalid")
      tree.finalize

      expect(tree.bsearch_indent {|largest| largest.to_s == "invalid" } ).to eq(1)
    end

    it "Knows a parent block" do
      tree = BlockIndentTree.new
      tree << FakeBlockForTree.new(indent: 2, length: 1, to_s: "super parent")
      tree << FakeBlockForTree.new(indent: 0, length: 1, to_s: "parent")
      tree << FakeBlockForTree.new(indent: 0, length: 5, to_s: "largest")
      tree.finalize

      expect(tree.at_indent(0)[1].to_s).to eq("largest")
      expect(tree.parent(indent: 0, index: 1).to_s).to eq("parent")
      expect(tree.parent(indent: 0, index: 0).to_s).to eq("super parent")
      expect(tree.parent(indent: 2, index: 0)).to be_falsey
    end

    it "sorts keys in descending order" do
      tree = BlockIndentTree.new
      tree << FakeBlockForTree.new(indent: 3, length: 1, to_s: "1 + 1")
      tree << FakeBlockForTree.new(indent: 2, length: 1, to_s: "1 + 1")
      tree << FakeBlockForTree.new(indent: 1, length: 1, to_s: "1 + 1")
      tree << FakeBlockForTree.new(indent: 0, length: 1, to_s: "1 + 1")
      tree.finalize

      expect(tree.keys).to eq([3, 2, 1, 0])
    end

    it "sorts values ascending length" do
      tree = BlockIndentTree.new
      tree << FakeBlockForTree.new(indent: 0, length: 4, to_s: "largest")
      tree << FakeBlockForTree.new(indent: 0, length: 2, to_s: "1 + 1")
      tree << FakeBlockForTree.new(indent: 0, length: 3, to_s: "1 + 1")
      tree << FakeBlockForTree.new(indent: 0, length: 1, to_s: "1 + 1")
      tree.finalize

      expect(tree.at_indent(0).map(&:length)).to eq([1,2,3,4])
      expect(tree.at_indent(1)).to eq([])
      expect(tree.largest.to_s).to eq("largest")
      expect(tree.largest_at_indent(0).to_s).to eq("largest")
      expect(tree.to_s).to eq("largest")
    end
  end
end
