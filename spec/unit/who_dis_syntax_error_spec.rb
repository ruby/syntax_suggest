# frozen_string_literal: true

require_relative "../spec_helper.rb"

module SyntaxErrorSearch
  RSpec.describe WhoDisSyntaxError do
    it  "determines the type of syntax error" do
      expect(
        WhoDisSyntaxError.new("def foo;").call.error_symbol
      ).to eq(:missing_end)

      expect(
        WhoDisSyntaxError.new("def foo; end; end").call.error_symbol
      ).to eq(:unmatched_end)
    end
  end
end
