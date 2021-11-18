# frozen_string_literal: true

require_relative "../spec_helper"

module DeadEnd

  RSpec.describe RangeDiff do
    it "sticks out on the left" do
      range = RangeDiff.new(753..9231, by: 754..9231).call
      expect(range.difference).to eq([753..753])
    end

    it "sticks out on the right" do
      range = RangeDiff.new(754..9237, by: 754..9231).call
      expect(range.difference).to eq([9232..9237])
    end

    it "sticks out on both" do
      range = RangeDiff.new(-10..10, by: -8..8).call
      expect(range.difference).to eq([-10..-9, 9..10])
    end

    it "does not overlap" do
      range = RangeDiff.new(-10..10, by: 28..88).call
      expect(range.difference).to eq([])
    end
  end

  class SplitTreeAtIndent
    def initialize(tree: , code_lines: , &block)
      @code_lines = code_lines
      @lambda = block
      @tree = tree
      @blocks = []
    end

    def call
      indent = invalid_indent
      index = index_at_indent(indent)

      block = @tree.at_indent(indent)[index]
      parent = @tree.parent(indent: indent, index: index)
      if !parent
        @blocks << block
      else
      end
    end

    def index_at_indent(indent)
      index = @tree.at_indent(indent).bsearch_index do |block|
        if @lambda.call(block)
          false
        else
          true
        end
      end
    end

    def invalid_indent
      @indent ||= @tree.keys.bsearch do |indent|
        block = @tree.largest_at_indent(indent)
        if @lambda.call(block)
          false
        else
          true
        end
      end
    end
  end

  RSpec.describe SplitTreeAtIndent do
    it "sorts keys in descending order" do
    end
  end
end
