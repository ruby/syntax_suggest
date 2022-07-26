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

    it "missing `do` highlights more than `end` simple" do
      source = <<~'EOM'
        describe "things" do
          it "blerg" do
          end

          it "flerg"
          end

          it "zlerg" do
          end
        end
      EOM
      io = StringIO.new
      DeadEnd.call(
        io: io,
        source: source
      )
      out = io.string
      expect(out).to include(<<~EOM)
           1  describe "things" do
           2    it "blerg" do
           3    end
        ❯  5    it "flerg"
        ❯  6    end
           8    it "zlerg" do
           9    end
           10  end
      EOM
    end

    it "missing `do` highlights more than `end`, with internal contents" do
      source = <<~'EOM'
        describe "things" do
          it "blerg" do
          end

          it "flerg"
            doesnt
            show
            extra
            stuff()
            that_s
            not
            critical
            inside
          end

          it "zlerg" do
            foo
          end
        end
      EOM
      io = StringIO.new
      DeadEnd.call(
        io: io,
        source: source
      )
      out = io.string

      expect(out).to include(<<~EOM)
           1  describe "things" do
           2    it "blerg" do
           3    end
        ❯  5    it "flerg"
        ❯  14   end
           16   it "zlerg" do
           18   end
           19  end
      EOM
    end

    it "works with valid code" do
      source = <<~'EOM'
        class OH
          def hello
          end
          def hai
          end
        end
      EOM

      io = StringIO.new
      DeadEnd.call(
        io: io,
        source: source
      )
      out = io.string

      expect(out).to include(<<~EOM)
        Syntax OK
      EOM
    end

    it "squished do regression" do
      source = <<~'EOM'
        def call
          trydo
            @options = CommandLineParser.new.parse
            options.requires.each { |r| require!(r) }
            load_global_config_if_exists
            options.loads.each { |file| load(file) }
            @user_source_code = ARGV.join(' ')
            @user_source_code = 'self' if @user_source_code == ''
            @callable = create_callable
            init_rexe_context
            init_parser_and_formatters
            # This is where the user's source code will be executed; the action will in turn call `execute`.
            lookup_action(options.input_mode).call unless options.noop
            output_log_entry
          end # one
        end # two
      EOM

      io = StringIO.new
      DeadEnd.call(
        io: io,
        source: source
      )
      out = io.string

      expect(out).to eq(<<~'EOM'.indent(2))
        1  def call
      ❯ 2    trydo
      ❯ 15   end # one
        16 end
      EOM
    end

    it "handles mismatched }" do
      source = <<~EOM
        class Blerg
          Foo.call do {
          puts lol
          class Foo
          end # two
        end # three
      EOM

      io = StringIO.new
      DeadEnd.call(
        io: io,
        source: source
      )

      expect(io.string).to include(<<~'EOM')
          1  class Blerg
        ❯ 2    Foo.call do {
          4    class Foo
          5    end # two
          6  end # three
      EOM
    end

    it "handles no spaces between blocks and trailing slash" do
      source = <<~'EOM'
        require "rails_helper"
        RSpec.describe Foo, type: :model do
          describe "#bar" do
            context "context" do
              it "foos the bar with a foo and then bazes the foo with a bar to"\
                "fooify the barred bar" do
                travel_to DateTime.new(2020, 10, 1, 10, 0, 0) do
                  foo = build(:foo)
                end
              end
            end
          end
          describe "#baz?" do
            context "baz has barred the foo" do
              it "returns true" do # <== HERE
            end
          end
        end
      EOM

      io = StringIO.new
      DeadEnd.call(
        io: io,
        source: source
      )

      expect(io.string).to include(<<~'EOM')
           2  RSpec.describe Foo, type: :model do
          13    describe "#baz?" do
        ❯ 14      context "baz has barred the foo" do
          16      end
          17    end
          18  end
      EOM
    end

    it "handles no spaces between blocks" do
      source = <<~'EOM'
        context "foo bar" do
          it "bars the foo" do
            travel_to DateTime.new(2020, 10, 1, 10, 0, 0) do
            end
          end
        end
        context "test" do
          it "should" do
        end
      EOM
      io = StringIO.new
      DeadEnd.call(
        io: io,
        source: source
      )

      expect(io.string).to include(<<~'EOM')
          7  context "test" do
        ❯ 8    it "should" do
          9  end
      EOM
    end

    it "finds hanging def in this project" do
      source = fixtures_dir.join("this_project_extra_def.rb.txt").read

      io = StringIO.new
      DeadEnd.call(
        io: io,
        source: source
      )

      expect(io.string).to include(<<~'EOM')
           1  module SyntaxErrorSearch
           3    class DisplayInvalidBlocks
          17      def call
          34      end
        ❯ 36      def filename
          38      def code_with_filename
          45      end
          63    end
          64  end
      EOM
    end

    it "Format Code blocks real world example" do
      source = <<~'EOM'
        require 'rails_helper'
        RSpec.describe AclassNameHere, type: :worker do
          describe "thing" do
            context "when" do
              let(:thing) { stuff }
              let(:another_thing) { moarstuff }
              subject { foo.new.perform(foo.id, true) }
              it "stuff" do
                subject
                expect(foo.foo.foo).to eq(true)
              end
            end
          end # line 16 accidental end, but valid block
            context "stuff" do
              let(:thing) { create(:foo, foo: stuff) }
              let(:another_thing) { create(:stuff) }
              subject { described_class.new.perform(foo.id, false) }
              it "more stuff" do
                subject
                expect(foo.foo.foo).to eq(false)
              end
            end
          end # mismatched due to 16
        end
      EOM

      io = StringIO.new
      DeadEnd.call(
        io: io,
        source: source
      )

      expect(io.string).to include(<<~'EOM')
            1  require 'rails_helper'
            2
            3  RSpec.describe AclassNameHere, type: :worker do
         ❯  4    describe "thing" do
         ❯ 16    end # line 16 accidental end, but valid block
         ❯ 30    end # mismatched due to 16
           31  end
      EOM
    end

    it "returns syntax error in outer block without inner block" do
      source = <<~'EOM'
        Foo.call
          def foo
            puts "lol"
            puts "lol"
          end # one
        end # two
      EOM

      io = StringIO.new
      DeadEnd.call(
        io: io,
        source: source
      )

      expect(io.string).to include(<<~'EOM')
          1  Foo.call
        ❯ 6  end # two
      EOM
    end

    it "finds multiple syntax errors" do
      source = <<~'EOM'
        describe "hi" do
          Foo.call
          end
        end
        it "blerg" do
          Bar.call
          end
        end
      EOM

      io = StringIO.new
      DeadEnd.call(
        io: io,
        source: source
      )

      expect(io.string).to include(<<~'EOM')
          1  describe "hi" do
        ❯ 2    Foo.call
        ❯ 3    end
          4  end
      EOM

      expect(io.string).to include(<<~'EOM')
          5  it "blerg" do
        ❯ 6    Bar.call
        ❯ 7    end
          8  end
      EOM
    end

    it "finds a naked end" do
      source = <<~'EOM'
        def foo
          end # one
        end # two
      EOM

      io = StringIO.new
      DeadEnd.call(
        io: io,
        source: source
      )

      expect(io.string).to include(<<~'EOM')
        ❯ end # one
      EOM
    end

    it "is harder" do
      source = <<~EOM
        class Blerg
          Foo.call }
            print haha
            print lol
          end # one
          print lol
          class Foo
          end # two
        end # three
      EOM

      io = StringIO.new
      DeadEnd.call(
        io: io,
        source: source
      )

      puts io.string
      raise "not implemented"
    end

    it "handles mismatched |" do
      source = <<~EOM
        class Blerg
          Foo.call do |a
            print lol
          end # one
          print lol
          class Foo
          end # two
        end # three
      EOM

      io = StringIO.new
      DeadEnd.call(
        io: io,
        source: source
      )

      expect(io.string).to include(<<~'EOM')
        Unmatched `|', missing `|' ?
        Unmatched keyword, missing `end' ?

          1  class Blerg
        ❯ 2    Foo.call do |a
          5    class Foo
          6    end # two
          7  end # three
        Unmatched `end', missing keyword (`do', `def`, `if`, etc.) ?

          1  class Blerg
        ❯ 3    end # one
          5    class Foo
          6    end # two
          7  end # three
      EOM

      raise("this should be one failure, not two")
    end
  end
end
