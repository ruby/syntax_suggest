# frozen_string_literal: true

require_relative "../spec_helper"

module DeadEnd
  RSpec.describe WhoDisSyntaxError do
    context "determines the type of syntax error to be an unmatched end" do
      it "with missing or extra end's" do
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

      it "with unexpected rescue" do
        source = <<~EOM
          def foo
            if bar
              "baz"
            else
              "foo"
          rescue FooBar
            nil
          end
        EOM

        expect(
          WhoDisSyntaxError.new(source).call.error_symbol
        ).to eq(:unmatched_syntax)

        expect(
          WhoDisSyntaxError.new(source).call.unmatched_symbol
        ).to eq(:end)
      end
    end

    context "determines the type of syntax error to be an unmatched pipe" do
      it "with unexpected 'end'" do
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

      it "with unexpected local variable or method" do
        source = <<~EOM
          class Blerg
             [].each do |a
              puts a
            end
          end
        EOM

        expect(
          DeadEnd.invalid_type(source).error_symbol
        ).to eq(:unmatched_syntax)

        expect(
          DeadEnd.invalid_type(source).unmatched_symbol
        ).to eq(:|)
      end
    end

    context "determines the type of syntax error to be an unmatched bracket" do
      it "with missing bracket" do
        source = <<~EOM
          module Hey
            class Foo
              def initialize
                [1,2,3
              end

              def call
              end
            end
          end
        EOM

        expect(
          DeadEnd.invalid_type(source).error_symbol
        ).to eq(:unmatched_syntax)

        expect(
          DeadEnd.invalid_type(source).unmatched_symbol
        ).to eq(:"[")
      end

      it "with naked bracket" do
        source = <<~EOM
          def initialize
            ]
          end
        EOM

        expect(
          DeadEnd.invalid_type(source).error_symbol
        ).to eq(:unmatched_syntax)

        expect(
          DeadEnd.invalid_type(source).unmatched_symbol
        ).to eq(:"]")
      end
    end
  end
end
