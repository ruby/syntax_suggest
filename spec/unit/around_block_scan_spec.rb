# frozen_string_literal: true

require_relative "../spec_helper.rb"

module SyntaxErrorSearch
  RSpec.describe AroundBlockScan do
    it "captures multiple empty and hidden lines" do
      source_string = <<~EOM
        def foo
          Foo.call

            puts "lol"

          end
        end
      EOM

      code_lines = code_line_array(source_string)
      block = CodeBlock.new(lines: code_lines[3])
      expand = AroundBlockScan.new(code_lines: code_lines, block: block)
      expand.scan_while { true }

      expect(expand.before_index).to eq(0)
      expect(expand.after_index).to eq(6)
      expect(expand.code_block.to_s).to eq(source_string)
    end

    it "only takes what you ask" do
      source_string = <<~EOM
        def foo
          Foo.call

            puts "lol"

          end
        end
      EOM

      code_lines = code_line_array(source_string)
      block = CodeBlock.new(lines: code_lines[3])
      expand = AroundBlockScan.new(code_lines: code_lines, block: block)
      expand.scan_while {|line| line.not_empty? }

      expect(expand.code_block.to_s).to eq(<<~EOM.indent(4))
        puts "lol"
      EOM
    end

    it "skips what you want" do
      source_string = <<~EOM
        def foo
          Foo.call

            puts "haha"
            # hide me

            puts "lol"

          end
        end
      EOM

      code_lines = code_line_array(source_string)
      code_lines[4].mark_invisible

      block = CodeBlock.new(lines: code_lines[3])
      expand = AroundBlockScan.new(code_lines: code_lines, block: block)
      expand.skip(:empty?)
      expand.skip(:hidden?)
      expand.scan_while {|line| line.indent >= block.current_indent }

      expect(expand.code_block.to_s).to eq(<<~EOM.indent(4))

        puts "haha"

        puts "lol"

      EOM
    end
  end
end
