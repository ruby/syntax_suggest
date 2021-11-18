# frozen_string_literal: true

require_relative "../spec_helper"

module DeadEnd
  RSpec.describe PartitionArraySearch do
    it "partitions and searches" do
      count = 0
      partition = PartitionArraySearch.new(["a", "a"])
      partition.call {|x| count +=1; x.join.include?("a") }
      expect(partition.match).to eq(["a", "a"])
      expect(count).to eq(2)

      count = 0
      array = [
        "b1", "b2", "b3", "b4", "b5", "b6", "b7", "b8", "b9", "a12", "b10", "b11"
      ]
      partition = PartitionArraySearch.new(array)
      partition.call {|x| count += 1; x.join.include?("a") }
      expect(partition.match).to eq(["a12"])
      expect(count).to be < array.length;
      expect(count).to eq(6);
    end
  end
end
