# frozen_string_literal: true

require_relative "../spec_helper.rb"

module SyntaxErrorSearch
  RSpec.describe "EndBlockParse" do
    it "finds blocks based on `end` keyword" do
      source = fixtures_dir.join("trailing-string.rb.txt").read
      code_lines = code_line_array(source)
      end_blocks = EndBlockParse.new(source: source, code_lines: code_lines)

      block = end_blocks.pop
      expect(block.to_s).to eq(<<~EOM.indent(8))
        travel_to DateTime.new(2020, 10, 1, 10, 0, 0) do
          office = build(:office)
        end
      EOM

      block.mark_invisible

      block = end_blocks.pop
      expect(block.to_s).to eq(<<~EOM.indent(6))
        it "should receive a time in UTC format and return the time with the"\\
          "office's UTC offset substracted from it" do
        end
      EOM

      block.mark_invisible

      block = end_blocks.pop
      expect(block.to_s).to eq(<<~EOM.indent(4))
        context "timezones workaround" do
        end
      EOM

      block.mark_invisible

      block = end_blocks.pop
      expect(block.to_s).to eq(<<~EOM.indent(4))
        context "more than 15 min have passed since appointment start time" do
          it "returns true" do
        end
      EOM
    end

    it "blerg" do
      source = <<~EOM
        Foo.call
          def foo
            puts "lol"
            puts "lol"
        end # one
      EOM

      code_lines = code_line_array(source)
      end_blocks = EndBlockParse.new(source: source, code_lines: code_lines)

      # Handle invalid internal (actual bug), missing end
      #
      #   context "more than 15 min have passed since appointment start time" do
      #     it "returns true" do
      #   end
      #
      # - Try internal
      # - Try search from bottom
      #
      # Handle mis-indent, invalid internal, valid external, unmatched end
      #
      #   Foo.call
      #     def foo
      #       puts "lol"
      #       puts "lol"
      #   end # one
      #   end
      #
      # - Try internal
      # - Try search from bottom
      #
      # Handle mis-indent, valid internal, nothing is invalid
      #
      #   "office's UTC offset substracted from it" do
      #   travel_to DateTime.new(2020, 10, 1, 10, 0, 0) do
      #     office = build(:office)
      #   end
      #
      # - Try search from bottom
      #

      block = end_blocks.pop
      expect(block.to_s).to eq(<<~EOM)
         def foo
           puts "lol"
           puts "lol"
       end # one
      EOM
    end
  end
end
