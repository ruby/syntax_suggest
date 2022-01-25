# frozen_string_literal: true

require_relative "../spec_helper"

module DeadEnd
  RSpec.describe BlockDocument do
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
