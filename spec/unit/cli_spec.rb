# frozen_string_literal: true

require_relative "../spec_helper"

module DeadEnd
  class FakeExit
    def initialize
      @called = false
      @value = nil
    end

    def exit(value = nil)
      @called = true
      @value = value
    end

    def called?
      @called
    end

    attr_reader :value
  end

  RSpec.describe Cli do
    it "parses valid code" do
      Dir.mktmpdir do |dir|
        dir = Pathname(dir)
        file = dir.join("script.rb")
        file.write("puts 'lol'")

        io = StringIO.new
        exit_obj = FakeExit.new
        Cli.new(
          io: io,
          argv: [file.to_s],
          exit_obj: exit_obj
        ).call

        expect(exit_obj.called?).to be_truthy
        expect(exit_obj.value).to eq(0)
        expect(io.string.strip).to eq("Syntax OK")
      end
    end

    it "parses invalid code" do
      file = fixtures_dir.join("this_project_extra_def.rb.txt")

      io = StringIO.new
      exit_obj = FakeExit.new
      Cli.new(
        io: io,
        argv: [file.to_s],
        exit_obj: exit_obj
      ).call

      out = io.string
      debug_display(out)

      expect(exit_obj.called?).to be_truthy
      expect(exit_obj.value).to eq(1)
      expect(out.strip).to include("❯ 36      def filename")
    end

    # We cannot execute the parser here
    # because it calls `exit` and it will exit
    # our tests, however we can assert that the
    # parser has the right value for version
    it "-v version" do
      io = StringIO.new
      exit_obj = FakeExit.new
      parser = Cli.new(
        io: io,
        argv: ["-v"],
        exit_obj: exit_obj
      ).parser

      expect(parser.version).to include(DeadEnd::VERSION.to_s)
    end

    it "DEAD_END_RECORD_DIR" do
      io = StringIO.new
      exit_obj = FakeExit.new
      cli = Cli.new(
        io: io,
        argv: [],
        env: {"DEAD_END_RECORD_DIR" => "hahaha"},
        exit_obj: exit_obj
      ).parse

      expect(exit_obj.called?).to be_falsey
      expect(cli.options[:record_dir]).to eq("hahaha")
    end

    it "--record-dir=<dir>" do
      io = StringIO.new
      exit_obj = FakeExit.new
      cli = Cli.new(
        io: io,
        argv: ["--record=lol"],
        exit_obj: exit_obj
      ).parse

      expect(exit_obj.called?).to be_falsey
      expect(cli.options[:record_dir]).to eq("lol")
    end

    it "terminal default to respecting TTY" do
      io = StringIO.new
      exit_obj = FakeExit.new
      cli = Cli.new(
        io: io,
        argv: [],
        exit_obj: exit_obj
      ).parse

      expect(exit_obj.called?).to be_falsey
      expect(cli.options[:terminal]).to eq(DeadEnd::DEFAULT_VALUE)
    end

    it "--terminal" do
      io = StringIO.new
      exit_obj = FakeExit.new
      cli = Cli.new(
        io: io,
        argv: ["--terminal"],
        exit_obj: exit_obj
      ).parse

      expect(exit_obj.called?).to be_falsey
      expect(cli.options[:terminal]).to be_truthy
    end

    it "--no-terminal" do
      io = StringIO.new
      exit_obj = FakeExit.new
      cli = Cli.new(
        io: io,
        argv: ["--no-terminal"],
        exit_obj: exit_obj
      ).parse

      expect(exit_obj.called?).to be_falsey
      expect(cli.options[:terminal]).to be_falsey
    end

    it "--help outputs help" do
      io = StringIO.new
      exit_obj = FakeExit.new
      Cli.new(
        io: io,
        argv: ["--help"],
        exit_obj: exit_obj
      ).call

      expect(exit_obj.called?).to be_truthy
      expect(io.string).to include("Usage: dead_end <file> [options]")
    end

    it "<empty args> outputs help" do
      io = StringIO.new
      exit_obj = FakeExit.new
      Cli.new(
        io: io,
        argv: [],
        exit_obj: exit_obj
      ).call

      expect(exit_obj.called?).to be_truthy
      expect(io.string).to include("Usage: dead_end <file> [options]")
    end
  end
end
