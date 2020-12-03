# frozen_string_literal: true

require_relative "../spec_helper.rb"

module SyntaxErrorSearch

  RSpec.describe "EndBlockParse" do
    it "finds blocks based on `end` keyword" do
      source = <<~EOM
        describe "cat" # 1
          Cat.call     # 2
          end          # 3
        end            # 4
                       # 5
        it "dog" do    # 6
          Dog.call     # 7
          end          # 8
        end            # 9
      EOM
      lex = LexAll.call(source: source)

      puts lex.last.last.class

      expect(lex.first.first).to eq([1, 0])
      expect(lex.last.first).to eq([9, 0])
    end
  end
end
