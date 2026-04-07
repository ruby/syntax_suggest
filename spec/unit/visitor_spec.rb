# frozen_string_literal: true

require_relative "../spec_helper"

module SyntaxSuggest
  RSpec.describe Visitor do
    def visit(source)
      ast, _tokens = Prism.parse_lex(source).value
      visitor = Visitor.new
      visitor.visit(ast)
      visitor
    end

    describe "#consecutive_lines" do
      it "detects dot-leading multi-line chains" do
        visitor = visit(<<~RUBY)
          User
            .where(name: "Earlopain")
            .first
        RUBY

        expect(visitor.consecutive_lines).to eq([1, 2])
      end

      it "detects dot-trailing multi-line chains" do
        visitor = visit(<<~RUBY)
          User.
            where(name: "Earlopain").
            first
        RUBY

        expect(visitor.consecutive_lines).to eq([1, 2])
      end

      it "handles chains separated by comments" do
        visitor = visit(<<~RUBY)
          User.
            # comment
            where(name: "Earlopain").
            # another comment
            first
        RUBY

        # The AST sees through comments — every line except
        # the last is consecutive regardless of interleaved comments.
        expect(visitor.consecutive_lines).to eq([1, 2, 3, 4])
      end

      it "returns empty for single-line calls" do
        visitor = visit(<<~RUBY)
          User.where(name: "Earlopain").first
        RUBY

        expect(visitor.consecutive_lines).to eq([])
      end

      it "returns empty when there is no method chain" do
        visitor = visit(<<~RUBY)
          puts "hello"
          puts "world"
        RUBY

        expect(visitor.consecutive_lines).to eq([])
      end

      it "handles deeply nested chains" do
        visitor = visit(<<~RUBY)
          User
            .where(name: "Earlopain")
            .order(:created_at)
            .limit(10)
            .first
        RUBY

        expect(visitor.consecutive_lines).to eq([1, 2, 3, 4])
      end
    end

    describe "#endless_def_keyword_locs" do
      it "records the def location for endless methods" do
        visitor = visit(<<~RUBY)
          def square(x) = x * x
        RUBY

        expect(visitor.endless_def_keyword_locs.length).to eq(1)
        expect(visitor.endless_def_keyword_locs.first.start_line).to eq(1)
      end

      it "does not record regular method definitions" do
        visitor = visit(<<~RUBY)
          def square(x)
            x * x
          end
        RUBY

        expect(visitor.endless_def_keyword_locs).to be_empty
      end

      it "records multiple endless methods" do
        visitor = visit(<<~RUBY)
          def square(x) = x * x
          def double(x) = x * 2
        RUBY

        expect(visitor.endless_def_keyword_locs.length).to eq(2)
      end

      it "distinguishes endless from regular in the same source" do
        visitor = visit(<<~RUBY)
          def square(x) = x * x
          def cube(x)
            x * x * x
          end
        RUBY

        expect(visitor.endless_def_keyword_locs.length).to eq(1)
        expect(visitor.endless_def_keyword_locs.first.start_line).to eq(1)
      end
    end
  end
end
