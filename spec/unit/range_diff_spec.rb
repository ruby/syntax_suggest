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
end
