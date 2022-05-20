# frozen_string_literal: true

require_relative "../spec_helper"

module DeadEnd
  RSpec.describe IndentTree do
    it "large both" do
      source = <<~'EOM'
        [
          one,
          two,
          three
        ].each do |i|
          print i {
        end
      EOM

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document)

      expect(tree.peek.to_s).to eq(<<~'EOM'.indent(2))
        three
      EOM

      expect(tree.step.to_s).to eq(<<~'EOM'.indent(2))
          one,
          two,
          three
      EOM

      expect(tree.peek.to_s).to eq(<<~'EOM'.indent(2))
        print i {
      EOM

      expect(tree.step.to_s).to eq(<<~'EOM'.indent(0))
          print i {
        end
      EOM

      expect(tree.peek.to_s).to eq(<<~'EOM'.indent(2))
          one,
          two,
          three
      EOM

      expect(tree.step.to_s).to eq(<<~'EOM'.indent(0))
        [
          one,
          two,
          three
        ].each do |i|
      EOM

      expect(tree.step.to_s).to eq(<<~'EOM'.indent(0))
        [
          one,
          two,
          three
        ].each do |i|
          print i {
        end
      EOM
    end

    it "finds missing do in an rspec context same indent when the problem is in the middle and blocks HAVE inner contents" do
      source = <<~'EOM'
        describe "things" do
          it "blerg" do
            print foo1
          end # one

          it "flerg"
            print foo2
          end # two

          it "zlerg" do
            print foo3
          end # three
        end
      EOM

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document)

      expect(tree.peek.to_s).to eq(<<~'EOM'.indent(4))
        print foo2
      EOM
      node = tree.step

      expect(node.to_s).to eq(<<~'EOM'.indent(2))
          it "flerg"
            print foo2
      EOM

      node = tree.peek
      expect(node.to_s).to eq(<<~'EOM'.indent(4))
          print foo3
      EOM
      node = tree.step

      expect(node.to_s).to eq(<<~'EOM'.indent(2))
        it "zlerg" do
          print foo3
        end # three
      EOM

      node = tree.peek
      expect(node.to_s).to eq(<<~'EOM'.indent(4))
          print foo1
      EOM
      node = tree.step

      expect(node.to_s).to eq(<<~'EOM'.indent(2))
        it "blerg" do
          print foo1
        end # one
      EOM

      node = tree.peek
      expect(node.to_s).to eq(<<~'EOM'.indent(2))
        end # two
      EOM

      node = tree.step

      expect(node.to_s).to eq(<<~'EOM'.indent(2))
        it "blerg" do
          print foo1
        end # one
        it "flerg"
          print foo2
        end # two
      EOM

      node = tree.peek
      expect(node.to_s).to eq(<<~'EOM'.indent(2))
        it "blerg" do
          print foo1
        end # one
        it "flerg"
          print foo2
        end # two
      EOM

      node = tree.step

      expect(node.to_s).to eq(<<~'EOM'.indent(2))
        it "blerg" do
          print foo1
        end # one
        it "flerg"
          print foo2
        end # two
        it "zlerg" do
          print foo3
        end # three
      EOM

      node = tree.peek
      expect(node.to_s).to eq(<<~'EOM'.indent(2))
        it "blerg" do
          print foo1
        end # one
        it "flerg"
          print foo2
        end # two
        it "zlerg" do
          print foo3
        end # three
      EOM

      node = tree.step
      expect(node.to_s).to eq(<<~'EOM')
        describe "things" do
          it "blerg" do
            print foo1
          end # one
          it "flerg"
            print foo2
          end # two
          it "zlerg" do
            print foo3
          end # three
        end
      EOM
    end

    it "rexe missing if microcase" do
      source = <<~'EOM'
        parser.on('-c', '--clear_options', "Clear all previous command line options") do |v|
          options.clear
        end # one

        parser.on('-f', '--input_file FILESPEC',
            'Use this file instead of stdin; autodetects YAML and JSON file extensions') do |v|
          unless File.exist?(v)
            raise "File #{v} does not exist."
          end # two
          options.input_filespec = v
          options.input_format = autodetect_file_format(v)


          # missing if here: if [:json, :yaml].include?(options.input_format)
            options.input_mode = :one_big_string
          end # three
        end # four
      EOM

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document)

      expect(tree.peek.to_s).to eq(<<~'EOM'.indent(4))
          options.input_mode = :one_big_string
      EOM

      expect(tree.step.to_s).to eq(<<~'EOM'.indent(2))
        options.input_filespec = v
        options.input_format = autodetect_file_format(v)
          options.input_mode = :one_big_string
      EOM

      expect(tree.peek.to_s).to eq(<<~'EOM'.indent(4))
        'Use this file instead of stdin; autodetects YAML and JSON file extensions') do |v|
      EOM

      expect(tree.step.to_s).to eq(<<~'EOM'.indent(0))
        parser.on('-f', '--input_file FILESPEC',
            'Use this file instead of stdin; autodetects YAML and JSON file extensions') do |v|
      EOM

      expect(tree.peek.to_s).to eq(<<~'EOM'.indent(4))
        raise "File #{v} does not exist."
      EOM

      expect(tree.step.to_s).to eq(<<~'EOM'.indent(2))
        unless File.exist?(v)
          raise "File #{v} does not exist."
        end # two
      EOM

      node = tree.peek
      expect(node.to_s).to eq(<<~'EOM'.indent(2))
        end # three
      EOM
      node = tree.step

      expect(node.to_s).to eq(<<~'EOM'.indent(2))
        unless File.exist?(v)
          raise "File #{v} does not exist."
        end # two
        options.input_filespec = v
        options.input_format = autodetect_file_format(v)
          options.input_mode = :one_big_string
        end # three
      EOM

      expect(tree.peek).to eq(node)
      node = tree.step

      expect(node.to_s).to eq(<<~'EOM'.indent(0))
        parser.on('-f', '--input_file FILESPEC',
            'Use this file instead of stdin; autodetects YAML and JSON file extensions') do |v|
          unless File.exist?(v)
            raise "File #{v} does not exist."
          end # two
          options.input_filespec = v
          options.input_format = autodetect_file_format(v)
            options.input_mode = :one_big_string
          end # three
        end # four
      EOM

      expect(tree.peek.to_s).to eq(<<~'EOM'.indent(2))
          options.clear
      EOM
      node = tree.step

      expect(node.to_s).to eq(<<~'EOM'.indent(0))
        parser.on('-c', '--clear_options', "Clear all previous command line options") do |v|
          options.clear
        end # one
      EOM
    end

    # If you put an indented "print" in there then
    # the problem goes away, I think it's fine to not handle
    # this (hopefully rare) case. If we showed you there was a problem
    # on this line, deleting it would actually fix the problem
    # even if the resultant code would be misindented
    #
    # We could also handle it in post though if we want to
    it "ambiguous end, only a problem if nothing internal" do
      source = <<~'EOM'
        class Cow
          end # one
        end # two
      EOM
      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call

      node = tree.root

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:one_invalid_parent)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:self)
      expect(node.to_s).to eq(<<~'EOM')
        end # two
      EOM
    end

    it "ambiguous kw" do
      source = <<~'EOM'
        class Cow
          def speak
        end
      EOM
      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call

      node = tree.root

      diagnose = DiagnoseNode.new(node).call
      expect(node.parents.length).to eq(2)
      expect(diagnose.problem).to eq(:one_invalid_parent)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:self)
      expect(node.to_s).to eq(<<~'EOM')
        class Cow
      EOM
    end

    it "fork invalid" do
      source = <<~'EOM'
        class Cow
          def speak
            print "moo"
        end

        class Buffalo
            print "buffalo"
          end # buffalo one
        end
      EOM
      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call

      node = tree.root

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:multiple_invalid_parents)
      forks = diagnose.next

      node = forks.first

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:invalid_inside_split_pair)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:one_invalid_parent)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:self)
      expect(node.to_s).to eq(<<~'EOM'.indent(2))
        def speak
      EOM

      node = forks.last

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:invalid_inside_split_pair)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:one_invalid_parent)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:self)
      expect(node.to_s).to eq(<<~'EOM'.indent(2))
        end # buffalo one
      EOM
    end

    it "invalid if and else" do
      source = <<~'EOM'
        if true
          print (
        else
          print }
        end
      EOM

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document)

      expect(tree.peek.to_s).to eq(<<~'EOM'.indent(2))
        print }
      EOM

      last = tree.step
      expect(last.to_s).to eq(<<~'EOM'.indent(0))
          print (
        else
          print }
      EOM

      expect(tree.peek.to_s).to eq(<<~'EOM'.indent(0))
        end
      EOM

      last = tree.step
      expect(last.to_s).to eq(<<~'EOM'.indent(0))
        if true
          print (
        else
          print }
        end
      EOM
    end

    it "(smaller) finds random pipe (|) wildly misindented" do
      source = <<~'EOM'
        class LanguagePack::Ruby < LanguagePack::Base
          def add_node_js_binary
            print add_node_js_binary
          end # one

          def add_yarn_binary
            return [] if yarn_preinstalled?
        | # problem is here
            if Pathname(build_path).join("yarn.lock").exist? || bundler.has_gem?('webpacker')
              [@yarn_installer.name]
            else
              []
            end # two
        end # three misindented but fine

          def node_preinstall_bin_path
            print node_preinstall_bin_path
          end # four
          alias :node_js_preinstalled? :node_preinstall_bin_path
        end # five
      EOM

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document)

      expect(tree.peek.to_s).to eq(<<~'EOM'.indent(6))
        []
      EOM
      last = tree.step
      expect(last.to_s).to eq(<<~'EOM'.indent(4))
          [@yarn_installer.name]
        else
          []
      EOM

      expect(tree.peek.to_s).to eq(<<~'EOM'.indent(4))
        end # two
      EOM

      last = tree.step
      expect(last.to_s).to eq(<<~'EOM'.indent(4))
        if Pathname(build_path).join("yarn.lock").exist? || bundler.has_gem?('webpacker')
          [@yarn_installer.name]
        else
          []
        end # two
      EOM

      expect(tree.peek.to_s).to eq(last.to_s)

      last = tree.step
      expect(last.to_s).to eq(<<~'EOM'.indent(0))
            return [] if yarn_preinstalled?
        | # problem is here
            if Pathname(build_path).join("yarn.lock").exist? || bundler.has_gem?('webpacker')
              [@yarn_installer.name]
            else
              []
            end # two
      EOM

      expect(tree.peek.to_s).to eq(<<~'EOM'.indent(4))
        print node_preinstall_bin_path
      EOM

      last = tree.step
      expect(last.to_s).to eq(<<~'EOM'.indent(2))
          def node_preinstall_bin_path
            print node_preinstall_bin_path
          end # four
      EOM

      expect(tree.peek.to_s).to eq(<<~'EOM'.indent(4))
          print add_node_js_binary
      EOM

      last = tree.step
      expect(last.to_s).to eq(<<~'EOM'.indent(2))
          def add_node_js_binary
            print add_node_js_binary
          end # one
      EOM

      expect(tree.peek.to_s).to eq(<<~'EOM'.indent(2))
          def node_preinstall_bin_path
            print node_preinstall_bin_path
          end # four
      EOM

      last = tree.step
      expect(last.to_s).to eq(<<~'EOM'.indent(2))
        def node_preinstall_bin_path
          print node_preinstall_bin_path
        end # four
        alias :node_js_preinstalled? :node_preinstall_bin_path
      EOM

      last = tree.step
      expect(last.to_s).to eq(<<~'EOM'.indent(0))
          def add_yarn_binary
            return [] if yarn_preinstalled?
        | # problem is here
            if Pathname(build_path).join("yarn.lock").exist? || bundler.has_gem?('webpacker')
              [@yarn_installer.name]
            else
              []
            end # two
      EOM

      last = tree.step
      expect(last.to_s).to eq(<<~'EOM'.indent(0))
          def node_preinstall_bin_path
            print node_preinstall_bin_path
          end # four
          alias :node_js_preinstalled? :node_preinstall_bin_path
        end # five
      EOM

      last = tree.step
      expect(last.to_s).to eq(<<~'EOM'.indent(0))
        class LanguagePack::Ruby < LanguagePack::Base
          def add_node_js_binary
            print add_node_js_binary
          end # one
          def add_yarn_binary
            return [] if yarn_preinstalled?
        | # problem is here
            if Pathname(build_path).join("yarn.lock").exist? || bundler.has_gem?('webpacker')
              [@yarn_installer.name]
            else
              []
            end # two
        end # three misindented but fine
      EOM

      last = tree.step
      expect(last.to_s).to eq(<<~'EOM'.indent(0))
        class LanguagePack::Ruby < LanguagePack::Base
          def add_node_js_binary
            print add_node_js_binary
          end # one
          def add_yarn_binary
            return [] if yarn_preinstalled?
        | # problem is here
            if Pathname(build_path).join("yarn.lock").exist? || bundler.has_gem?('webpacker')
              [@yarn_installer.name]
            else
              []
            end # two
        end # three misindented but fine
          def node_preinstall_bin_path
            print node_preinstall_bin_path
          end # four
          alias :node_js_preinstalled? :node_preinstall_bin_path
        end # five
      EOM

      ## That's the whole document

      # HEY: Weird that this is picking the wrong end
      tree = tree.call # Resolve all steps
      search = IndentSearch.new(tree: tree).call

      # expect(search.finished.join).to eq(<<~'EOM'.indent(0))
      #     def add_yarn_binary
      #       return [] if yarn_preinstalled?
      #   | # problem is here
      #       if Pathname(build_path).join("yarn.lock").exist? || bundler.has_gem?('webpacker')
      #         [@yarn_installer.name]
      #       else
      #         []
      #       end # two
      #   end # five
      # EOM
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
      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:invalid_inside_split_pair)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:remove_pseudo_pair)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:invalid_inside_split_pair)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:one_invalid_parent)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:invalid_inside_split_pair)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:remove_pseudo_pair)
      expect(node.parents.length).to eq(4)

      diagnose = DiagnoseNode.new(node).call
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:self)
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
      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:one_invalid_parent)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:invalid_inside_split_pair)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:one_invalid_parent)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:invalid_inside_split_pair)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:remove_pseudo_pair)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:invalid_inside_split_pair)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:invalid_inside_split_pair)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:remove_pseudo_pair)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:invalid_inside_split_pair)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:one_invalid_parent)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:self)
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

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:invalid_inside_split_pair)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:invalid_inside_split_pair)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:one_invalid_parent)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:one_invalid_parent)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:self)
      expect(node.to_s).to eq(<<~'EOM'.indent(4))
        def filename
      EOM
    end

    it "regression dog test" do
      source = <<~'EOM'
        class Dog
          def bark
            print "woof"
        end
      EOM
      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call

      node = tree.root

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:invalid_inside_split_pair)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:one_invalid_parent)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:self)
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

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:invalid_inside_split_pair)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:one_invalid_parent)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:self)
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
      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:invalid_inside_split_pair)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:one_invalid_parent)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:self)
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
      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:one_invalid_parent)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:invalid_inside_split_pair)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:one_invalid_parent)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:one_invalid_parent)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:self)
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
      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:one_invalid_parent)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:one_invalid_parent)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:invalid_inside_split_pair)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:one_invalid_parent)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:one_invalid_parent)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:invalid_inside_split_pair)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:one_invalid_parent)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:one_invalid_parent)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:self)
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

        node = tree.root

        diagnose = DiagnoseNode.new(node).call
        expect(diagnose.problem).to eq(:one_invalid_parent)
        node = diagnose.next[0]

        diagnose = DiagnoseNode.new(node).call
        expect(diagnose.problem).to eq(:invalid_inside_split_pair)
        node = diagnose.next[0]

        diagnose = DiagnoseNode.new(node).call
        expect(diagnose.problem).to eq(:one_invalid_parent)
        node = diagnose.next[0]

        diagnose = DiagnoseNode.new(node).call
        expect(diagnose.problem).to eq(:one_invalid_parent)
        node = diagnose.next[0]

        diagnose = DiagnoseNode.new(node).call
        expect(diagnose.problem).to eq(:self)
        expect(node.to_s).to eq(<<~'EOM'.indent(2))
          def on_args_add(arguments, argument)
        EOM
      end
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

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:one_invalid_parent)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:one_invalid_parent)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:self)
      expect(node.to_s).to eq(<<~'EOM')
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

      node = tree.root

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:one_invalid_parent)
      node = diagnose.next[0]

      diagnose = DiagnoseNode.new(node).call
      expect(diagnose.problem).to eq(:self)
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
