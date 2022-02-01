# frozen_string_literal: true

require_relative "../spec_helper"

module DeadEnd
  RSpec.describe IndentTree do
      it "(smaller) finds random pipe (|) wildly misindented" do
        source = <<~'EOM'
        class LanguagePack::Ruby < LanguagePack::Base
          def allow_git(&blk)
            git_dir = ENV.delete("GIT_DIR") # can mess with bundler
            blk.call
            ENV["GIT_DIR"] = git_dir
          end

          def add_dev_database_addon
            pg_adapters.any? {|a| bundler.has_gem?(a) } ? ['heroku-postgresql'] : []
          end

          def pg_adapters
            [
              "pg",
              "activerecord-jdbcpostgresql-adapter",
              "jdbc-postgres",
              "jdbc-postgresql",
              "jruby-pg",
              "rjack-jdbc-postgres",
              "tgbyte-activerecord-jdbcpostgresql-adapter"
            ]
          end

          def add_node_js_binary
            return [] if node_js_preinstalled?

            if Pathname(build_path).join("package.json").exist? ||
                bundler.has_gem?('execjs') ||
                bundler.has_gem?('webpacker')
              [@node_installer.binary_path]
            else
              []
            end
          end

          def add_yarn_binary
            return [] if yarn_preinstalled?
        |
            if Pathname(build_path).join("yarn.lock").exist? || bundler.has_gem?('webpacker')
              [@yarn_installer.name]
            else
              []
            end
        end

          def has_yarn_binary?
            add_yarn_binary.any?
          end

          def node_preinstall_bin_path
            return @node_preinstall_bin_path if defined?(@node_preinstall_bin_path)

            legacy_path = "#{Dir.pwd}/#{NODE_BP_PATH}"
            path        = run("which node").strip
            if path && $?.success?
              @node_preinstall_bin_path = path
            elsif run("#{legacy_path}/node -v") && $?.success?
              @node_preinstall_bin_path = legacy_path
            else
              @node_preinstall_bin_path = false
            end
          end
          alias :node_js_preinstalled? :node_preinstall_bin_path
        end
      EOM

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call

      node = tree.root

      expect(node.diagnose).to eq(:split_leaning)
      node = node.split_leaning

      expect(node.diagnose).to eq(:next_invalid)
      node = node.next_invalid

      expect(node.diagnose).to eq(:split_leaning)
      node = node.split_leaning

      expect(node.diagnose).to eq(:next_invalid)
      node = node.next_invalid

      expect(node.diagnose).to eq(:self)
      expect(node.to_s).to eq(<<~'EOM')
        |
      EOM
    end

    it "doesn't scapegoat rescue" do
      source = <<~'EOM'
        def compile
          instrument 'ruby.compile' do
            # check for new app at the beginning of the compile
            new_app?
            Dir.chdir(build_path)
            remove_vendor_bundle
            warn_bundler_upgrade
            warn_bad_binstubs
            install_ruby(slug_vendor_ruby, build_ruby_path)
            setup_language_pack_environment(
              ruby_layer_path: File.expand_path("."),
              gem_layer_path: File.expand_path("."),
              bundle_path: "vendor/bundle", }
              bundle_default_without: "development:test"
            )
            allow_git do
              install_bundler_in_app(slug_vendor_base)
              load_bundler_cache
              build_bundler
              post_bundler
              create_database_yml
              install_binaries
              run_assets_precompile_rake_task
            end
            config_detect
            best_practice_warnings
            warn_outdated_ruby
            setup_profiled(ruby_layer_path: "$HOME", gem_layer_path: "$HOME") # $HOME is set to /app at run time
            setup_export
            cleanup
            super
          end
        rescue => e
          warn_outdated_ruby
          raise e
        end
      EOM

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call

      node = tree.root

      node = tree.root
      expect(node.diagnose).to eq(:split_leaning)
      node = node.split_leaning

      expect(node.diagnose).to eq(:multiple)
      node = node.handle_multiple

      expect(node.diagnose).to eq(:split_leaning)
      node = node.split_leaning

      expect(node.diagnose).to eq(:next_invalid)
      node = node.next_invalid

      expect(node.diagnose).to eq(:split_leaning)
      node = node.split_leaning

      expect(node.diagnose).to eq(:multiple)
      expect(node.parents.length).to eq(4)

      node = node.handle_multiple

      expect(node.parents.length).to eq(1)
      expect(node.diagnose).to eq(:next_invalid)

      node = node.next_invalid
      expect(node.diagnose).to eq(:self)

      expect(node.to_s).to eq(<<~'EOM'.indent(6))
        bundle_path: "vendor/bundle", }
      EOM
    end

    it "finds random pipe (|) wildly misindented" do
      source = fixtures_dir.join("ruby_buildpack.rb.txt").read

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call

      node = tree.root
      expect(node.diagnose).to eq(:next_invalid)
      node = node.next_invalid

      expect(node.diagnose).to eq(:split_leaning)
      node = node.split_leaning

      expect(node.diagnose).to eq(:next_invalid)
      node = node.next_invalid

      expect(node.diagnose).to eq(:split_leaning)
      node = node.split_leaning

      expect(node.diagnose).to eq(:multiple)
      node = node.handle_multiple

      expect(node.diagnose).to eq(:split_leaning)
      node = node.split_leaning

      expect(node.diagnose).to eq(:split_leaning)
      node = node.split_leaning

      expect(node.diagnose).to eq(:multiple)
      node = node.handle_multiple

      expect(node.diagnose).to eq(:split_leaning)
      node = node.split_leaning

      expect(node.diagnose).to eq(:next_invalid)
      node = node.next_invalid

      expect(node.diagnose).to eq(:self)
      expect(node.to_s).to eq(<<~'EOM')
        |
      EOM
    end

    it "finds hanging def in this project" do
      source = fixtures_dir.join("this_project_extra_def.rb.txt").read

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call

      node = tree.root

      expect(node.diagnose).to eq(:split_leaning)
      node = node.split_leaning


      expect(node.diagnose).to eq(:split_leaning)
      node = node.split_leaning

      expect(node.diagnose).to eq(:next_invalid)
      node = node.next_invalid

      expect(node.diagnose).to eq(:next_invalid)
      node = node.next_invalid

      expect(node.diagnose).to eq(:self)
      expect(node.to_s).to eq(<<~'EOM'.indent(4))
        def filename
      EOM
    end


    it "regression dog test" do
      source = <<~'EOM'
        class Dog
          def bark
            puts "woof"
        end
      EOM
      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call

      node = tree.root
      expect(node.diagnose).to eq(:split_leaning)
      node = node.split_leaning

      expect(node.diagnose).to eq(:next_invalid)
      node = node.next_invalid

      expect(node.diagnose).to eq(:self)

      expect(node.to_s).to eq(<<~'EOM'.indent(2))
        def bark
      EOM
    end

    it "regression test ambiguous end" do
      # Even though you would think the first step is to
      # expand the "print" line, we base priority off of
      # "next_indent" so the actual highest "next indent" line
      # comes from "end # one" which captures "print", then it
      # expands out from there
      source = <<~'EOM'
        def call
            print "lol"
          end # one
        end # two
      EOM

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call

      node = tree.root

      expect(node.diagnose).to eq(:split_leaning)
      node = node.split_leaning

      expect(node.diagnose).to eq(:next_invalid)
      node = node.next_invalid

      expect(node.diagnose).to eq(:self)
      expect(node.to_s).to eq(<<~'EOM'.indent(2))
        end # one
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

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call

      node = tree.root
      expect(node.diagnose).to eq(:split_leaning)
      node = node.split_leaning

      expect(node.diagnose).to eq(:next_invalid)
      node = node.next_invalid

      expect(node.diagnose).to eq(:self)
      expect(node.to_s).to eq(<<~'EOM'.indent(2))
        end # one
      EOM
    end

    it "simpler rexe regression" do
      source = <<~'EOM'
        module Helpers
          def output_formats
            @output_formats ||= {
                'a' => :amazing_print,
                'i' => :inspect,
                'j' => :json,
                'J' => :pretty_json,
                'm' => :marshal,
                'n' => :none,
                'p' => :puts,         # default
                'P' => :pretty_print,
                's' => :to_s,
                'y' => :yaml,
            }
          end


          def formatters
            @formatters ||=  {
                amazing_print: ->(obj)  { obj.ai + "\n" },
                inspect:       ->(obj)  { obj.inspect + "\n" },
                json:          ->(obj)  { obj.to_json },
                marshal:       ->(obj)  { Marshal.dump(obj) },
                none:          ->(_obj) { nil },
                pretty_json:   ->(obj)  { JSON.pretty_generate(obj) },
                pretty_print:  ->(obj)  { obj.pretty_inspect },
                puts:          ->(obj)  { require 'stringio'; sio = StringIO.new; sio.puts(obj); sio.string },
                to_s:          ->(obj)  { obj.to_s + "\n" },
                yaml:          ->(obj)  { obj.to_yaml },
            }
          end


          def format_requires
            @format_requires ||= {
                json:          'json',
                pretty_json:   'json',
                amazing_print: 'amazing_print',
                pretty_print:  'pp',
                yaml:          'yaml'
            }
        end

        class CommandLineParser

          include Helpers

          attr_reader :lookups, :options

          def initialize
            @lookups = Lookups.new
            @options = Options.new
          end
        end
      EOM

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call

      node = tree.root
      expect(node.diagnose).to eq(:next_invalid)
      node = node.next_invalid

      expect(node.diagnose).to eq(:split_leaning)
      node = node.split_leaning

      expect(node.diagnose).to eq(:next_invalid)
      node = node.next_invalid

      expect(node.diagnose).to eq(:next_invalid)
      node = node.next_invalid

      expect(node.diagnose).to eq(:self)
      expect(node.to_s).to eq(<<~'EOM'.indent(2))
        def format_requires
      EOM
    end

    it "rexe regression" do
      lines = fixtures_dir.join("rexe.rb.txt").read.lines
      lines.delete_at(148 - 1)
      source = lines.join

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call

      node = tree.root

      expect(node.diagnose).to eq(:next_invalid)
      node = node.next_invalid

      expect(node.diagnose).to eq(:next_invalid)
      node = node.next_invalid

      expect(node.diagnose).to eq(:split_leaning)
      node = node.split_leaning

      expect(node.diagnose).to eq(:next_invalid)
      node = node.next_invalid

      expect(node.diagnose).to eq(:next_invalid)
      node = node.next_invalid


      expect(node.diagnose).to eq(:split_leaning)
      node = node.split_leaning

      expect(node.diagnose).to eq(:next_invalid)
      node = node.next_invalid

      expect(node.diagnose).to eq(:next_invalid)
      node = node.next_invalid

      expect(node.diagnose).to eq(:self)
      expect(node.to_s).to eq(<<~'EOM'.indent(4))
        def format_requires
      EOM
    end

    it "syntax_tree.rb.txt for performance validation" do
      file = fixtures_dir.join("syntax_tree.rb.txt")
      lines = file.read.lines
      lines.delete_at(768 - 1)
      source = lines.join

      tree = nil
      document = nil
      debug_perf do
        code_lines = CleanDocument.new(source: source).call.lines
        document = BlockDocument.new(code_lines: code_lines).call
        tree = IndentTree.new(document: document).call
      end

      node = tree.root

      expect(node.diagnose).to eq(:next_invalid)
      node = node.next_invalid

      expect(node.diagnose).to eq(:split_leaning)
      node = node.split_leaning

      expect(node.diagnose).to eq(:next_invalid)
      node = node.next_invalid

      expect(node.diagnose).to eq(:next_invalid)
      node = node.next_invalid

      expect(node.diagnose).to eq(:self)
      expect(node.to_s).to eq(<<~'EOM'.indent(2))
        def on_args_add(arguments, argument)
      EOM
    end

    it "invalid if/else end with surrounding code" do
      source = <<~'EOM'
        class Foo
          def to_json(*opts)
            { type: :args, parts: parts, loc: location }.to_json(*opts)
          end
        end

        def on_args_add(arguments, argument)
          if arguments.parts.empty?
            Args.new(parts: [argument], location: argument.location)
          else

            Args.new(
              parts: arguments.parts << argument,
              location: arguments.location.to(argument.location)
            )
          end
          # Missing end here, comments are erased via CleanDocument

        class ArgsAddBlock
          attr_reader :arguments

          attr_reader :block

          attr_reader :location

          def initialize(arguments:, block:, location:)
            @arguments = arguments
            @block = block
            @location = location
          end
        end
      EOM

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call

      node = tree.root

      expect(node.diagnose).to eq(:next_invalid)
      node = node.next_invalid

      expect(node.diagnose).to eq(:next_invalid)
      node = node.next_invalid

      expect(node.diagnose).to eq(:self)
      expect(node.to_s).to eq(<<~'EOM')
        def on_args_add(arguments, argument)
      EOM
    end

    it "valid if/else end" do
      source = <<~'EOM'
        def on_args_add(arguments, argument)
          if arguments.parts.empty?

            Args.new(parts: [argument], location: argument.location)
          else

            Args.new(
              parts: arguments.parts << argument,
              location: arguments.location.to(argument.location)
            )
          end
        end
      EOM

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call

      blocks = document.to_a
      expect(blocks.length).to eq(1)
      node = document.root
      expect(node.leaning).to eq(:equal)
      expect(node.parents.length).to eq(3)
      expect(node.parents.map(&:valid?)).to eq([false, true , false])

      expect(node.parents[0].to_s).to eq(<<~'EOM')
        def on_args_add(arguments, argument)
      EOM

      expect(document.root.parents[1].to_s).to eq(<<~'EOM'.indent(2))
        if arguments.parts.empty?
          Args.new(parts: [argument], location: argument.location)
        else
          Args.new(
            parts: arguments.parts << argument,
            location: arguments.location.to(argument.location)
          )
        end
      EOM

      expect(document.root.parents[2].to_s).to eq(<<~'EOM')
        end
      EOM

      inside = document.root.parents[1]
      expect(inside.parents[0].to_s).to eq(<<~'EOM'.indent(2))
        if arguments.parts.empty?
      EOM

      expect(inside.parents[1].to_s).to eq(<<~'EOM'.indent(2))
          Args.new(parts: [argument], location: argument.location)
        else
          Args.new(
            parts: arguments.parts << argument,
            location: arguments.location.to(argument.location)
          )
      EOM

      expect(inside.parents[2].to_s).to eq(<<~'EOM'.indent(2))
        end
      EOM
    end

    it "extra space before end" do
      source = <<~'EOM'
        Foo.call
          def foo
            print "lol"
            print "lol"
           end # one
        end # two
      EOM
      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call

      node = tree.root

      expect(node.diagnose).to eq(:next_invalid)
      node = node.next_invalid

      expect(node.diagnose).to eq(:self)
      expect(node.to_s).to eq(<<~'EOM')
        end # two
      EOM
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
      tree = IndentTree.new(document: document)
      tree.call

      blocks = document.to_a
      expect(blocks.length).to eq(1)

      expect(document.root.parents.length).to eq(3)
      expect(document.root.parents[0].to_s).to eq(<<~'EOM')
        if true              # 0
          print 'huge 1'     # 1
        end                  # 2
      EOM

      expect(document.root.parents[1].to_s).to eq(<<~'EOM')
        if true              # 4
          print 'huge 2'     # 5
        end                  # 6
      EOM

      expect(document.root.parents[2].to_s).to eq(<<~'EOM')
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
      tree = IndentTree.new(document: document)
      tree.call

      # blocks = document.to_a
      expect(document.root.to_s).to eq(code_lines.join)
      expect(document.to_a.length).to eq(1)
      expect(document.root.parents.length).to eq(3)
    end
  end
end
