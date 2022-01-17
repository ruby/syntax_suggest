# frozen_string_literal: true

require_relative "../spec_helper"

module DeadEnd
  RSpec.describe BlockNode do
    it "Can figure out it's own next_indentation" do
      source = <<~'EOM'
        if true
          print 'huge'
          print 'huge'
        end
      EOM

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call

      expect(document.map(&:next_indent)).to eq([0, 2, 2, 0])

      source = <<~'EOM'
        if true
          print 'huge'
        end
      EOM

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call

      expect(document.map(&:next_indent)).to eq([0, 0, 0])
    end
  end
end
