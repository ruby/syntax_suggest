# frozen_string_literal: true

require_relative "../spec_helper"

module DeadEnd
  RSpec.describe BlockDocument do
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

      blocks = document.to_a

      node = document.capture(node: blocks[3], captured: blocks[1..2])

      expect(node.to_s).to eq(code_lines[1..3].join)
      expect(node.start_index).to eq(1)
      expect(node.indent).to eq(2)
      expect(node.next_indent).to eq(0)
      expect(document.map(&:itself).length).to eq(3)

      # Document has changed, rebuild blocks to array
      blocks = document.to_a
      node = document.capture(node: blocks[1], captured: [blocks[0], blocks[2]])

      expect(node.to_s).to eq(code_lines.join)
      expect(node.inner.length).to eq(3)
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

      blocks = document.to_a
      document.capture(node: blocks[1], captured: [blocks[0], blocks[2]])
      blocks = document.to_a
      document.capture(node: blocks[2], captured: [blocks[1], blocks[3]])
      blocks = document.to_a
      document.capture(node: blocks[3], captured: [blocks[2], blocks[4]])

      blocks = document.to_a
      expect(blocks.length).to eq(3)
      root = document.root
      document.capture(node: root, captured: blocks[1..-1])

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

    it "Block document dequeues from bottom to top" do
      code_lines = CodeLine.from_source(<<~'EOM')
        Foo.call
        end
      EOM

      document = BlockDocument.new(code_lines: code_lines).call
      one = document.queue.pop
      expect(one.to_s.strip).to eq("end")

      two = document.queue.pop
      expect(two.to_s.strip).to eq("Foo.call")

      expect(one.above).to eq(two)
      expect(two.below).to eq(one)

      expect(document.queue.pop).to eq(nil)
    end
  end
end
