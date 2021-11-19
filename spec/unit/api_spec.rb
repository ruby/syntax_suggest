# frozen_string_literal: true

require_relative "../spec_helper"
require "ruby-prof"

module DeadEnd
  RSpec.describe "Top level DeadEnd api" do
    it "has a `handle_error` interface" do
      fake_error = Object.new
      def fake_error.message
        "#{__FILE__}:216: unterminated string meets end of file "
      end

      io = StringIO.new
      DeadEnd.handle_error(
        fake_error,
        re_raise: false,
        io: io
      )

      expect(io.string.strip).to eq("Syntax OK")
    end
  end
end
