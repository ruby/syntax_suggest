# frozen_string_literal: true

require_relative "../spec_helper"

module DeadEnd
  RSpec.describe IndentSearch do
    def tmp_capture_context(finished)
      code_lines = finished.first.steps[0].block.lines
      blocks = finished.map(&:node).map {|node| CodeBlock.new(lines: node.lines )}
      lines = CaptureCodeContext.new(blocks: blocks , code_lines: code_lines).call
      lines
    end

    it "finds missing do in an rspec context same indent when the problem is in the middle and blocks do not have inner contents" do
      source = <<~'EOM'
        describe "things" do
          it "blerg" do
          end # one

          it "flerg"
          end # two

          it "zlerg" do
          end # three
        end
      EOM

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call
      search = IndentSearch.new(tree: tree).call

      expect(search.finished.join).to eq(<<~'EOM'.indent(2))
        end # two
      EOM
    end

    it "finds missing do in an rspec context same indent when the problem is in the middle and blocks HAVE inner contents" do
      source = <<~'EOM'
        describe "things" do
          it "blerg" do
            print foo
          end # one

          it "flerg"
            print foo
          end # two

          it "zlerg" do
            print foo
          end # three
        end
      EOM

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call
      search = IndentSearch.new(tree: tree).call

      expect(search.finished.join).to eq(<<~'EOM'.indent(2))
        end # two
      EOM
    end

    it "finds a mis-matched def" do
      source = <<~'EOM'
        def foo
          def blerg
        end
      EOM

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call
      search = IndentSearch.new(tree: tree).call

      expect(search.finished.join).to eq(<<~'EOM'.indent(2))
        def blerg
      EOM
    end

    it "finds a typo def" do
      source = <<~'EOM'
        defzfoo
          puts "lol"
        end
      EOM

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call
      search = IndentSearch.new(tree: tree).call

      expect(search.finished.join).to eq(<<~'EOM'.indent(0))
        end
      EOM

      lines = tmp_capture_context(search.finished)
      expect(lines.join).to eq(<<~'EOM')
        defzfoo
        end
      EOM
    end

    it "finds a naked end" do
      source = <<~'EOM'
        def foo
          end # one
        end # two
      EOM

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call
      search = IndentSearch.new(tree: tree).call

      expect(search.finished.join).to eq(<<~'EOM'.indent(0))
        end # two
      EOM

      lines = tmp_capture_context(search.finished)
      expect(lines.join).to eq(<<~'EOM')
        IDK what I want here
      EOM
    end

    it "finds multiple syntax errors" do
      source = <<~'EOM'
        describe "hi" do
          Foo.call
          end # one
        end # two

        it "blerg" do
          Bar.call
          end # three
        end # four
      EOM

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call
      search = IndentSearch.new(tree: tree).call

      expect(search.finished.join).to eq(<<~'EOM'.indent(2))
        end # one
        end # three
      EOM

      lines = tmp_capture_context(search.finished)
      expect(lines.join).to include(<<~'EOM'.indent(2))
        Foo.call
        end # one
      EOM

      expect(lines.join).to include(<<~'EOM'.indent(2))
        Bar.call
        end # three
      EOM
    end

    it "doesn't just return an empty `end`" do
      source = <<~'EOM'
        Foo.call
        end # one
      EOM

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call
      search = IndentSearch.new(tree: tree).call

      expect(search.finished.join).to eq(<<~'EOM'.indent(0))
        end # one
      EOM

      lines = tmp_capture_context(search.finished)
      expect(lines.join).to include(<<~'EOM'.indent(0))
        Foo.call
        end # one
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

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call
      search = IndentSearch.new(tree: tree).call

      expect(search.finished.join).to eq(<<~'EOM'.indent(0))
        end # two
      EOM

      lines = tmp_capture_context(search.finished)
      expect(lines.join).to include(<<~'EOM'.indent(0))
        Foo.call
        end # two
      EOM
    end

    it "won't show valid code when two invalid blocks are splitting it" do
      source = <<~'EOM'
        {
          print (
        }

        print 'haha'

        {
          print )
        }
      EOM

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call
      search = IndentSearch.new(tree: tree).call

      expect(search.finished.join).to eq(<<~'EOM'.indent(0))
        {
          print (
        }
        {
          print )
        }
      EOM
    end

    it "only returns the problem line and not all lines on a long inner section" do
      source = <<~'EOM'
        {
          foo: :bar,
          bing: :baz,
          blat: :flat # problem
          florg: :blorg,
          bling: :blong
        }
      EOM

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call
      search = IndentSearch.new(tree: tree).call

      expect(search.finished.join).to eq(<<~'EOM'.indent(2))
        blat: :flat # problem
      EOM
    end

    it "invalid if and else" do
      source = <<~'EOM'
        if true
          puts (
        else
          puts }
        end
      EOM

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call
      search = IndentSearch.new(tree: tree).call

      expect(search.finished.length).to eq(2)
      expect(search.finished.first.to_s).to eq(<<~'EOM'.indent(2))
        puts (
      EOM

      expect(search.finished.last.to_s).to eq(<<~'EOM'.indent(2))
        puts }
      EOM
    end

    it "handles heredocs" do
      lines = fixtures_dir.join("rexe.rb.txt").read.lines
      lines.delete_at(85 - 1)
      source = lines.join

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call
      search = IndentSearch.new(tree: tree).call

      expect(search.finished.first.node.to_s).to eq(<<~'EOM'.indent(4))
        def input_modes
      EOM
    end

    it "handles derailed output issues/50" do
      source = fixtures_dir.join("derailed_require_tree.rb.txt").read

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call
      search = IndentSearch.new(tree: tree).call

      expect(search.finished.first.node.to_s).to eq(<<~'EOM'.indent(4))
        def initialize(name)
      EOM
    end

    it "handles multi-line-methods issues/64" do
      source = fixtures_dir.join("webmock.rb.txt").read

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call
      search = IndentSearch.new(tree: tree).call

      expect(search.finished.first.node.to_s).to eq(<<~'EOM'.indent(6))
        port: port
      EOM
    end

    it "returns good results on routes.rb" do
      source = fixtures_dir.join("routes.rb.txt").read

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call
      search = IndentSearch.new(tree: tree).call

      expect(search.finished.first.node.to_s).to eq(<<~'EOM'.indent(2))
        namespace :admin do
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
      search = IndentSearch.new(tree: tree).call

      expect(search.finished.first.node.to_s).to eq(<<~'EOM'.indent(6))
        bundle_path: "vendor/bundle", }
      EOM
    end

    it "finds hanging def in this project" do
      source = fixtures_dir.join("this_project_extra_def.rb.txt").read

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call
      search = IndentSearch.new(tree: tree).call

      expect(search.finished.first.node.to_s).to eq(<<~'EOM'.indent(4))
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
      search = IndentSearch.new(tree: tree).call

      expect(search.finished.first.node.to_s).to eq(<<~'EOM'.indent(2))
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
      search = IndentSearch.new(tree: tree).call

      expect(search.finished.first.node.to_s).to eq(<<~'EOM'.indent(2))
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
      search = IndentSearch.new(tree: tree).call

      expect(search.finished.first.node.to_s).to eq(<<~'EOM'.indent(2))
        end # one
      EOM
    end

    it "rexe regression" do
      lines = fixtures_dir.join("rexe.rb.txt").read.lines
      lines.delete_at(148 - 1)
      source = lines.join

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call
      search = IndentSearch.new(tree: tree).call

      expect(search.finished.first.node.to_s).to eq(<<~'EOM'.indent(4))
        def format_requires
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
      search = IndentSearch.new(tree: tree).call

      expect(search.finished.first.node.to_s).to eq(<<~'EOM')
        def on_args_add(arguments, argument)
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
      search = IndentSearch.new(tree: tree).call

      expect(search.finished.first.node.to_s).to eq(<<~'EOM')
        end # two
      EOM
    end

    it "finds random pipe (|) wildly misindented" do
      source = fixtures_dir.join("ruby_buildpack.rb.txt").read

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call
      search = IndentSearch.new(tree: tree).call

      expect(search.finished.first.node.to_s).to eq(<<~'EOM')
        |
      EOM
    end

    it "syntax tree search" do
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
        search = IndentSearch.new(tree: tree).call

        expect(search.finished.first.node.to_s).to eq(<<~'EOM'.indent(2))
          def on_args_add(arguments, argument)
        EOM
      end
    end

    it "finds missing comma in array" do
      source = <<~'EOM'
        def animals
          [
            cat,
            dog
            horse
          ]
        end
      EOM

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call

      search = IndentSearch.new(tree: tree).call

      expect(search.finished.first.node.to_s).to eq(<<~'EOM'.indent(4))
        cat,
        dog
        horse
      EOM
    end
  end
end
