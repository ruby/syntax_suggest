# frozen_string_literal: true

require_relative "../spec_helper"

module DeadEnd
  RSpec.describe LeftRightLexCount do
    it "leans unknown" do
      lr = LeftRightLexCount.new()
      lr.count_lines(
        CodeLine.from_source("[}")
      )
      expect(lr.leaning).to eq(:unknown)
    end

    it "leans right" do
      lr = LeftRightLexCount.new()
      lr.count_lines(
        CodeLine.from_source("}")
      )
      expect(lr.leaning).to eq(:right)
    end

    it "leans left" do
      lr = LeftRightLexCount.new()
      lr.count_lines(
        CodeLine.from_source("{")
      )
      expect(lr.leaning).to eq(:left)
    end

    it "leans equal" do
      lr = LeftRightLexCount.new()
      lr.count_lines(
        CodeLine.from_source("{{}}")
      )
      expect(lr.leaning).to eq(:equal)
    end
  end
end
