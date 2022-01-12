# frozen_string_literal: true

require_relative "../spec_helper"

module DeadEnd
  RSpec.describe "LexPairDiff" do
    it "leans unknown" do
      diff = LexPairDiff.from_lex(
        lex: LexAll.new(source: "[}").to_a,
        is_kw: false,
        is_end: false
      )
      expect(diff.leaning).to eq(:both)
    end

    it "leans right" do
      diff = LexPairDiff.from_lex(
        lex: LexAll.new(source: "}").to_a,
        is_kw: false,
        is_end: false
      )
      expect(diff.leaning).to eq(:right)
    end

    it "leans left" do
      diff = LexPairDiff.from_lex(
        lex: LexAll.new(source: "{").to_a,
        is_kw: false,
        is_end: false
      )
      expect(diff.leaning).to eq(:left)
    end

    it "leans equal" do
      diff = LexPairDiff.from_lex(
        lex: LexAll.new(source: "{}").to_a,
        is_kw: false,
        is_end: false
      )
      expect(diff.leaning).to eq(:equal)
    end
  end
end
