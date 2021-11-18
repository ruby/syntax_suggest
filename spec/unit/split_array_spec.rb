# frozen_string_literal: true

require_relative "../spec_helper"

module DeadEnd

  RSpec.describe SplitArray do
    it "cannot split empty array" do
      expect(SplitArray.new([]).can_split?).to be_falsey
    end

    it "cannot split one element array" do
      expect(SplitArray.new([1]).can_split?).to be_falsey
    end

    it "can split two element array" do
      split = SplitArray.new([1, 2])
      expect(split.can_split?).to be_truthy
      expect(split.first).to eq([1])
      expect(split.second).to eq([2])
    end

    it "can split odd numbered array" do
      split = SplitArray.new([1, 2, 3])
      expect(split.can_split?).to be_truthy
      expect(split.first).to eq([1])
      expect(split.second).to eq([2, 3])
    end
  end
end
