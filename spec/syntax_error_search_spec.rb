module SyntaxErrorSearch
  RSpec.describe SyntaxErrorSearch do
    it "has a version number" do
      expect(SyntaxErrorSearch::VERSION).not_to be nil
    end

    def ruby(script)
      `ruby -I#{lib_dir} -rdid_you_do #{script} 2>&1`
    end

    describe "foo" do
      around(:each) do |example|
        Dir.mktmpdir do |dir|
          @tmpdir = Pathname(dir)
          @script = @tmpdir.join("script.rb")
          example.run
        end
      end

      it "blerg" do
        @script.write <<~EOM
          describe "things" do
            it "blerg" do
            end

            it "flerg"
            end

            it "zlerg" do
            end
          end
        EOM

        require_rb = @tmpdir.join("require.rb")
        require_rb.write <<~EOM
          require_relative "./script.rb"
        EOM

        # out = ruby(require_rb)
        # puts out
      end
    end
  end

  RSpec.describe "code line" do
    it "detect" do
      source = CodeSource.new(<<~EOM)
        def foo
          puts 'lol'
        end
      EOM
      source.detect_invalid
      expect(source.code_lines.map(&:marked_invalid?)).to eq([false, false, false])

      source = CodeSource.new(<<~EOM)
        def foo
          end
        end
      EOM
      source.detect_invalid
      expect(source.code_lines.map(&:marked_invalid?)).to eq([false, true, false])

      source = CodeSource.new(<<~EOM)
        def foo
          def blerg
        end
      EOM
      source.detect_invalid
      expect(source.code_lines.map(&:marked_invalid?)).to eq([false, true, false])
    end

    it "frontier" do
      source = CodeSource.new(<<~EOM)
        def foo
          puts 'lol'
        end
      EOM
      block = source.next_frontier
      expect(block.lines).to eq([source.code_lines[1]])

      source.code_lines[1].mark_invisible

      block = source.next_frontier
      expect(block.lines).to eq(
        [source.code_lines[0], source.code_lines[2]])
    end

    it "frontier levels" do
      source_string = <<~EOM
        describe "hi" do
          Foo.call
          end
        end

        it "blerg" do
          Bar.call
          end
        end
      EOM

      source = CodeSource.new(source_string)

      block = source.next_frontier
      expect(block.to_s).to eq(<<~EOM.indent(2))
        Foo.call
        end
      EOM

      block = source.next_frontier
      expect(block.to_s).to eq(<<~EOM.indent(2))
        Bar.call
        end
      EOM
    end

    it "max indent to block" do
      source = CodeSource.new(<<~EOM)
        def foo
          puts 'lol'
        end
      EOM
      block = source.max_indent_to_block

      expect(block.lines).to eq([source.code_lines[1]])

      block = source.max_indent_to_block
      expect(block.lines).to eq([source.code_lines[0]])

      source = CodeSource.new(<<~EOM)
        def foo
          puts 'lol'
        end

        def bar
          puts 'boo'
        end
      EOM
      block = source.max_indent_to_block
      expect(block.lines).to eq([source.code_lines[1]])

      block = source.max_indent_to_block
      expect(block.lines).to eq([source.code_lines[5]])
    end


    describe "detect cases" do
      it "finds one invalid code block with typo def" do
        source_string = <<~EOM
          defzfoo
            puts "lol"
          end
        EOM
        source = CodeSource.new(source_string)
        source.detect_invalid

        expect(source.invalid_code.to_s).to eq(<<~EOM)
        defzfoo
        end
        EOM
      end

      it "finds TWO invalid code block with missing do at the depest indent" do
        source = <<~EOM
          describe "hi" do
            Foo.call
            end
          end

          it "blerg" do
            Bar.call
            end
          end
        EOM

        source = CodeSource.new(source)
        source.detect_invalid


        expect(source.invalid_code.to_s).to eq(<<~EOM.indent(2))
          Foo.call
          end
          Bar.call
          end
        EOM
      end

      it "finds one invalid code block with missing do at the depest indent" do
        source = <<~EOM
          describe "hi" do
            Foo.call
            end
          end

          it "blerg" do
          end
        EOM

        source = CodeSource.new(source)
        source.detect_invalid

        expect(source.code_lines[1].marked_invalid?).to be_truthy
        expect(source.code_lines[2].marked_invalid?).to be_truthy

        expect(source.invalid_code.to_s).to eq("  Foo.call\n  end\n")
      end
    end

    describe "foo" do
      it "doesn't mark valid code as invalid" do
        # Foo.call is valid, don't show in the output
        source = <<~EOM
          describe "hi"
            Foo.call do
            end
          end

          it "blerg" do
            Bar.call
            end
          end
        EOM

        source = CodeSource.new(source)
        source.detect_invalid

        expect(source.invalid_code.to_s).to eq(<<~EOM)
          describe "hi"
          end

          it "blerg" do
            Bar.call
            end
          end
        EOM
      end
    end
  end
end
