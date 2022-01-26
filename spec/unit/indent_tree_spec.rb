# frozen_string_literal: true

require_relative "../spec_helper"

module DeadEnd
  RSpec.describe BlockDocument do
    it "extra space before end" do
      source = <<~'EOM'
        Foo.call
          def foo
            print "lol"
            print "lol"
           end # one
        end # two
      EOM
      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call

      blocks = document.to_a
      expect(blocks.length).to eq(1)
      expect(document.root.leaning).to eq(:right)

      expect(document.root.inner.length).to eq(3)
      expect(document.root.inner[0].to_s).to eq(<<~'EOM')
        Foo.call
      EOM
      expect(document.root.inner[0].indent).to eq(0)


      expect(document.root.inner[1].to_s).to eq(<<~'EOM'.indent(2))
        def foo
          print "lol"
          print "lol"
         end # one
      EOM
      expect(document.root.inner[1].balanced?).to be_truthy
      expect(document.root.inner[1].indent).to eq(2)

      expect(document.root.inner[2].to_s).to eq(<<~'EOM')
        end # two
      EOM
      expect(document.root.inner[2].indent).to eq(0)
    end

    it "captures complicated" do
      source = <<~'EOM'
        if true              # 0
          print 'huge 1'     # 1
        end                  # 2

        if true              # 4
          print 'huge 2'     # 5
        end                  # 6

        if true              # 8
          print 'huge 3'     # 9
        end                  # 10
      EOM

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document)
      tree.call

      blocks = document.to_a
      expect(blocks.length).to eq(1)

      expect(document.root.inner.length).to eq(3)
      expect(document.root.inner[0].to_s).to eq(<<~'EOM')
        if true              # 0
          print 'huge 1'     # 1
        end                  # 2
      EOM

      expect(document.root.inner[1].to_s).to eq(<<~'EOM')
        if true              # 4
          print 'huge 2'     # 5
        end                  # 6
      EOM

      expect(document.root.inner[2].to_s).to eq(<<~'EOM')
        if true              # 8
          print 'huge 3'     # 9
        end                  # 10
      EOM
    end

    it "prioritizes indent" do
      code_lines = CodeLine.from_source(<<~'EOM')
        def foo
          end # one
        end # two
      EOM

      document = BlockDocument.new(code_lines: code_lines).call
      one = document.queue.pop
      expect(one.to_s.strip).to eq("end # one")
    end

    it "captures" do
      source = <<~'EOM'
        if true
          print 'huge 1'
          print 'huge 2'
          print 'huge 3'
        end
      EOM

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document)
      tree.call

      # blocks = document.to_a
      expect(document.root.to_s).to eq(code_lines.join)
      expect(document.to_a.length).to eq(1)
      expect(document.root.inner.length).to eq(3)
    end

    it "simple" do
      skip
      source = <<~'EOM'
        print 'lol'
        print 'lol'

        Foo.call # missing do
        end
      EOM

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      search = BlockSearch.new(document: document).call
      search.call

      expect(search.document.root).to eq(
        BlockNode.new(lines: code_lines[0..1], indent: 0).tap { |node|
          node.inner << BlockNode.new(lines: code_lines[0], indent: 0)
          node.right = BlockNode.new(lines: code_lines[1], indent: 0)
        }
      )
    end


  end
end
