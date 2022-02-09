# frozen_string_literal: true

require_relative "../spec_helper"

module DeadEnd
  RSpec.describe "Integration tests that don't spawn a process (like using the cli)" do
    it "does not timeout on massive files", slow: true do
      file = fixtures_dir.join("syntax_tree.rb.txt")
      lines = file.read.lines
      lines.delete_at(768 - 1)

      io = StringIO.new

      benchmark = Benchmark.measure do
        debug_perf do
          DeadEnd.call(
            io: io,
            source: lines.join,
            filename: file
          )
        end
        debug_display(io.string)
        debug_display(benchmark)
      end

      expect(io.string).to include(<<~'EOM')
             6  class SyntaxTree < Ripper
           727    class Args
           750    end
        ❯  754    def on_args_add(arguments, argument)
           776    class ArgsAddBlock
           810    end
          9233  end
      EOM
    end

    it "re-checks all block code, not just what's visible issues/95" do
      file = fixtures_dir.join("ruby_buildpack.rb.txt")
      io = StringIO.new

      debug_perf do
        benchmark = Benchmark.measure do
          DeadEnd.call(
            io: io,
            source: file.read,
            filename: file
          )
        end
        debug_display(io.string)
        debug_display(benchmark)
      end

      expect(io.string).to_not include("def ruby_install_binstub_path")
      expect(io.string).to include(<<~'EOM')
            16  class LanguagePack::Ruby < LanguagePack::Base
        ❯ 1069  |
          1344  end
      EOM
    end

    it "returns good results on routes.rb" do
      source = fixtures_dir.join("routes.rb.txt").read

      io = StringIO.new
      DeadEnd.call(
        io: io,
        source: source
      )
      debug_display(io.string)

      expect(io.string).to include(<<~'EOM')
            1  Rails.application.routes.draw do
          107    constraints -> { Rails.application.config.non_production } do
          111    end
        ❯ 113    namespace :admin do
          121  end
      EOM
    end

    it "handles multi-line-methods issues/64" do
      source = fixtures_dir.join("webmock.rb.txt").read

      io = StringIO.new
      DeadEnd.call(
        io: io,
        source: source
      )
      debug_display(io.string)

      expect(io.string).to include(<<~'EOM')
           1  describe "webmock tests" do
          22    it "body" do
          27      query = Cutlass::FunctionQuery.new(
        ❯ 28        port: port
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
        source: source
      )
      debug_display(io.string)

      expect(io.string).to include(<<~'EOM')
           5  module DerailedBenchmarks
           6    class RequireTree
        ❯ 13      def initialize(name)
          18      def self.reset!
          25      end
          73    end
          74  end
      EOM
    end

    it "handles heredocs" do
      lines = fixtures_dir.join("rexe.rb.txt").read.lines
      lines.delete_at(85 - 1)
      io = StringIO.new
      DeadEnd.call(
        io: io,
        source: lines.join
      )

      out = io.string
      debug_display(out)

      expect(out).to include(<<~EOM)
           16  class Rexe
           77    class Lookups
        ❯  78      def input_modes
           87      def input_formats
           94      end
          148    end
          551  end
      EOM
    end

    it "rexe" do
      lines = fixtures_dir.join("rexe.rb.txt").read.lines
      lines.delete_at(148 - 1)
      source = lines.join

      io = StringIO.new
      DeadEnd.call(
        io: io,
        source: source
      )
      out = io.string
      expect(out).to include(<<~EOM)
           16  class Rexe
           77    class Lookups
          124      def formatters
          137      end
        ❯ 140      def format_requires
          148    end
          551  end
      EOM
    end

    it "ambiguous end" do
      source = <<~'EOM'
        def call          # 0
            print "lol"   # 1
          end # one       # 2
        end # two         # 3
      EOM
      io = StringIO.new
      DeadEnd.call(
        io: io,
        source: source
      )
      out = io.string
      expect(out).to include(<<~EOM)
          1  def call          # 0
        ❯ 3    end # one       # 2
          4  end # two         # 3
      EOM
    end

    it "simple regression" do
      source = <<~'EOM'
        class Dog
          def bark
            puts "woof"
        end
      EOM
      io = StringIO.new
      DeadEnd.call(
        io: io,
        source: source
      )
      out = io.string
      expect(out).to include(<<~EOM)
          1  class Dog
        ❯ 2    def bark
          4  end
      EOM
    end
  end
end
