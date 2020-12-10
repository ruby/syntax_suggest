# frozen_string_literal: true

require_relative "../spec_helper.rb"

module DeadEnd
  RSpec.describe WhoDisSyntaxError do
    it  "determines the type of syntax error" do
      expect(
        WhoDisSyntaxError.new("def foo;").call.error_symbol
      ).to eq(:missing_end)

      expect(
        WhoDisSyntaxError.new("def foo; end; end").call.error_symbol
      ).to eq(:unmatched_syntax)

      expect(
        WhoDisSyntaxError.new("def foo; end; end").call.unmatched_symbol
      ).to eq(:end)
    end

    it "" do
      source = <<~EOM
        class Blerg
          Foo.call do |a
          end # one

          puts lol
          class Foo
          end # two
        end # three
      EOM

      expect(
        DeadEnd.invalid_type(source).error_symbol
      ).to eq(:unmatched_syntax)

      expect(
        DeadEnd.invalid_type(source).unmatched_symbol
      ).to eq(:|)
    end
  end
end
