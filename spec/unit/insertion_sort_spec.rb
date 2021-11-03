# frozen_string_literal: true

require_relative "../spec_helper"

module DeadEnd
  class CurrentIndex
    attr_reader :current_indent

    def initialize(value)
      @current_indent = value
    end

    def <=>(other)
      @current_indent <=> other.current_indent
    end
  end

  RSpec.describe CodeFrontier do
    it "works manually" do
      frontier = InsertionSort.new
      frontier << CurrentIndex.new(0)
      frontier << CurrentIndex.new(1)

      expect(frontier.to_a.map(&:current_indent)).to eq([0, 1])

      frontier << CurrentIndex.new(1)
      expect(frontier.to_a.map(&:current_indent)).to eq([0, 1, 1])

      frontier << CurrentIndex.new(0)
      expect(frontier.to_a.map(&:current_indent)).to eq([0, 0, 1, 1])

      frontier << CurrentIndex.new(10)
      expect(frontier.to_a.map(&:current_indent)).to eq([0, 0, 1, 1, 10])

      frontier << CurrentIndex.new(2)
      expect(frontier.to_a.map(&:current_indent)).to eq([0, 0, 1, 1, 2, 10])
    end

    it "handles lots of values" do
      frontier = InsertionSort.new
      values = [18, 18, 0, 18, 0, 18, 18, 18, 18, 16, 18, 8, 18, 8, 8, 8, 16, 6, 0, 0, 16, 16, 4, 14, 14, 12, 12, 12, 10, 12, 12, 12, 12, 8, 10, 10, 8, 8, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 8, 10, 6, 6, 6, 6, 6, 6, 8, 10, 8, 8, 10, 8, 10, 8, 10, 8, 6, 8, 8, 6, 8, 6, 6, 8, 0, 8, 0, 0, 8, 8, 0, 8, 0, 8, 8, 0, 8, 8, 8, 0, 8, 0, 8, 8, 8, 8, 8, 8, 8, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 8, 8, 8, 6, 8, 6, 6, 6, 6, 8, 6, 8, 6, 6, 4, 4, 6, 6, 4, 6, 4, 6, 6, 4, 6, 4, 4, 6, 6, 6, 6, 4, 4, 4, 2, 4, 4, 4, 4, 4, 4, 6, 6, 0, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 0, 0, 6, 6, 2]
      values.each do |v|
        frontier << CurrentIndex.new(v)
      end

      expect(frontier.to_a.map(&:current_indent)).to eq(values.sort)
    end
  end
end
