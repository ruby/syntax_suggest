require_relative "../spec_helper.rb"

module SyntaxErrorSearch
  RSpec.describe CodeSearch do
    # For code that's not perfectly formatted, we ideally want to do our best
    # These examples represent the results that exist today, but I would like to improve upon them
    describe "needs improvement" do
      describe "mis-matched-indentation" do
        it "stacked ends " do
          search = CodeSearch.new(<<~EOM)
            Foo.call
              def foo
                puts "lol"
                puts "lol"
            end
            end
          EOM
          search.call

          # Does not include the line with the error Foo.call
          expect(search.invalid_blocks.join).to eq(<<~EOM)
              def foo
            end
            end
          EOM
        end

        it "extra space before end" do
          search = CodeSearch.new(<<~EOM)
            Foo.call
              def foo
                puts "lol"
                puts "lol"
               end
            end
          EOM
          search.call

          # Does not include the line with the error Foo.call
          expect(search.invalid_blocks.join).to eq(<<~EOM.indent(3))
            end
          EOM
        end

        it "missing space before end" do
          search = CodeSearch.new(<<~EOM)
            Foo.call
              def foo
                puts "lol"
                puts "lol"
             end
            end
          EOM
          search.call

          # Does not include the line with the error Foo.call
          expect(search.invalid_blocks.join).to eq(<<~EOM)
            end
          EOM
        end
      end
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
