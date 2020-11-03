
require_relative "../spec_helper.rb"

module SyntaxErrorSearch
  RSpec.describe CodeSearch do
    it "does not go into an infinite loop" do
      search = CodeSearch.new(<<~EOM)
        Foo.call
          def foo
            puts "lol"
            puts "lol"
        end
        end
      EOM
      search.call

      expect(search.invalid_blocks.join).to eq(<<~EOM)
        end
      EOM
    end

    it "handles mis-matched-indentation-but-maybe-not-so-well" do
      search = CodeSearch.new(<<~EOM)
        Foo.call
          def foo
            puts "lol"
            puts "lol"
           end
        end
      EOM
      search.call

      expect(search.invalid_blocks.join).to eq(<<~EOM)
        end
      EOM
    end

    it "returns syntax error in outer block without inner block" do
      search = CodeSearch.new(<<~EOM)
        Foo.call
          def foo
            puts "lol"
            puts "lol"
          end
        end
      EOM
      search.call

      expect(search.invalid_blocks.join).to eq(<<~EOM)
        Foo.call
        end
      EOM
    end

    it "doesn't just return an empty `end`" do
      search = CodeSearch.new(<<~EOM)
        Foo.call

        end
      EOM
      search.call

      expect(search.invalid_blocks.join).to eq(<<~EOM)
        Foo.call
        end
      EOM
    end

    it "finds multiple syntax errors" do
      search = CodeSearch.new(<<~EOM)
        describe "hi" do
          Foo.call
          end
        end

        it "blerg" do
          Bar.call
          end
        end
      EOM
      search.call

      expect(search.invalid_blocks.join).to eq(<<~EOM.indent(2))
        Foo.call
        end
        Bar.call
        end
      EOM
    end

    it "finds a typo def" do
      search = CodeSearch.new(<<~EOM)
        defzfoo
          puts "lol"
        end
      EOM
      search.call

      expect(search.invalid_blocks.join).to eq(<<~EOM)
        defzfoo
        end
      EOM
    end

    it "finds a mis-matched def" do
      search = CodeSearch.new(<<~EOM)
        def foo
          def blerg
        end
      EOM
      search.call

      expect(search.invalid_blocks.join).to eq(<<~EOM.indent(2))
        def blerg
      EOM
    end

    it "finds a naked end" do
      search = CodeSearch.new(<<~EOM)
        def foo
          end
        end
      EOM
      search.call

      expect(search.invalid_blocks.join).to eq(<<~EOM.indent(2))
        end
      EOM
    end

    it "returns when no invalid blocks are found" do
      search = CodeSearch.new(<<~EOM)
        def foo
          puts 'lol'
        end
      EOM
      search.call

      expect(search.invalid_blocks).to eq([])
    end
  end
end
