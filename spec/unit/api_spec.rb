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

      def fake_error.is_a?(v)
        true
      end

      io = StringIO.new
      DeadEnd.handle_error(
        fake_error,
        re_raise: false,
        io: io
      )

      expect(io.string.strip).to eq("Syntax OK")
    end

    it "raises original error with warning if a non-syntax error is passed" do
      error = NameError.new("blerg")
      io = StringIO.new
      expect {
        DeadEnd.handle_error(
          error,
          re_raise: false,
          io: io
        )
      }.to raise_error { |e|
        expect(io.string).to include("Must pass a SyntaxError")
        expect(e).to eq(error)
      }
    end

    it "raises original error with warning if file is not found" do
      fake_error = SyntaxError.new
      def fake_error.message
        "#does/not/exist/lol/doesnotexist:216: unterminated string meets end of file "
      end

      io = StringIO.new
      expect {
        DeadEnd.handle_error(
          fake_error,
          re_raise: false,
          io: io
        )
      }.to raise_error { |e|
        expect(io.string).to include("Could not find filename")
        expect(e).to eq(fake_error)
      }
    end
  end
end
