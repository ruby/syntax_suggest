# frozen_string_literal: true

require_relative "../spec_helper"

module DeadEnd
  RSpec.describe "Integration tests that don't spawn a process (like using the cli)" do

    it "returns good results on routes.rb" do
      source = fixtures_dir.join("routes.rb.txt").read

      io = StringIO.new
      DeadEnd.call(
        io: io,
        source: source,
      )
      debug_display(io.string)

      expect(io.string).to include(<<~'EOM')
           1  Rails.application.routes.draw do
        ❯ 113    namespace :admin do
        ❯ 116    match "/foobar(*path)", via: :all, to: redirect { |_params, req|
        ❯ 120    }
          121  end
      EOM
    end

    it "handles multi-line-methods issues/64" do
      source = fixtures_dir.join("webmock.rb.txt").read

      io = StringIO.new
      DeadEnd.call(
        io: io,
        source: source,
      )
      debug_display(io.string)

      expect(io.string).to include(<<~'EOM')
           1  describe "webmock tests" do
          22    it "body" do
          27      query = Cutlass::FunctionQuery.new(
        ❯ 28        port: port
        ❯ 29        body: body
          30      ).call
          34    end
          35  end
      EOM
    end

    it "handles derailed output issues/50" do
      source = fixtures_dir.join("derailed_require_tree.rb.txt").read

      io = StringIO.new
      DeadEnd.call(
        io: io,
        source: source,
      )
      debug_display(io.string)

      expect(io.string).to include(<<~'EOM')
           5  module DerailedBenchmarks
           6    class RequireTree
           7      REQUIRED_BY = {}
           9      attr_reader   :name
          10      attr_writer   :cost
          11      attr_accessor :parent
        ❯ 13      def initialize(name)
        ❯ 18      def self.reset!
        ❯ 25      end
          73    end
          74  end
      EOM
    end

    it "re-checks all block code, not just what's visible issues/95" do
      file = fixtures_dir.join("ruby_buildpack.rb.txt")
      io = StringIO.new
      DeadEnd.call(
        io: io,
        source: file.read,
        filename: file
      )
      debug_display(io.string)

      expect(io.string).to_not include("def ruby_install_binstub_path")
      expect(io.string).to include(<<~'EOM')
        ❯ 1067    def add_yarn_binary
        ❯ 1068      return [] if yarn_preinstalled?
        ❯ 1069  |
        ❯ 1075    end
      EOM
    end
  end
end
