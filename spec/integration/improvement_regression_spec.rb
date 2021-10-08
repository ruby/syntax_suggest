# frozen_string_literal: true

require_relative "../spec_helper"

module DeadEnd
  RSpec.describe "Library only integration to test regressions and improvements" do
    it "handles derailed output issues/50" do
      source = fixtures_dir.join("derailed_require_tree.rb.txt").read

      io = StringIO.new
      DeadEnd.call(
        io: io,
        source: source,
        filename: "none"
      )

      expect(io.string).to include(<<~'EOM'.indent(4))
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
  end
end
