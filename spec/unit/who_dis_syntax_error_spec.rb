# frozen_string_literal: true

require_relative "../spec_helper.rb"

module DeadEnd
  RSpec.describe WhoDisSyntaxError do
    it "indentation lines for keyword 'def'" do
      source = <<~'EOM'
      class Dog       # 1
        def bark      # 2
          puts "woof" # 3
      end             # 4
      EOM

      expect(
        WhoDisSyntaxError.new(source).call.indentation_lines
      ).to eq([2])

      expect(
        WhoDisSyntaxError.new(source).call.indentation_indexes
      ).to eq([1])
    end

    it "indentation lines for keyword 'do'" do
      source = <<~'EOM'
      class Dog       # 1
        Foo.call do   # 2
          puts "woof" # 3
      end             # 4
      EOM

      expect(
        WhoDisSyntaxError.new(source).call.indentation_lines
      ).to eq([]) # :( Ruby gives no warnings here

      expect(
        WhoDisSyntaxError.new(source).call.indentation_indexes
      ).to eq([])
    end

    it "determines the type of syntax error" do
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

    it "determines error caused by missing | character" do
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
