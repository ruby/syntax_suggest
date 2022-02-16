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

    it "large both" do
      source = <<~'EOM'
        def dog
        end

        [
          one,
          two,
          three
        ].each do |i|
          print i {
        end

        def cat
        end
      EOM

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call
      search = IndentSearch.new(tree: tree).call

      # context = BlockNodeContext.new(search.finished[0]).call
      expect(search.finished.join).to eq(<<~'EOM'.indent(0))
        [
          one,
          two,
        ].each do |i|
          print i {
        end
      EOM
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

      context = BlockNodeContext.new(search.finished[0]).call
      expect(context.highlight.join).to eq(<<~'EOM'.indent(2))
        end # two
      EOM

      # expect(context.lines.join).to eq(<<~'EOM'.indent(2))
      #   it "flerg"
      #   end # two
      # EOM
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
      tree = IndentTree.new(document: document).call
      search = IndentSearch.new(tree: tree).call

      context = BlockNodeContext.new(search.finished[0]).call
      expect(context.highlight.join).to eq(<<~'EOM'.indent(2))
        end # two
      EOM

      # expect(context.lines.join).to eq(<<~'EOM'.indent(2))
      #   it "flerg"
      #     print foo2
      #   end # two
      # EOM
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

      context = BlockNodeContext.new(search.finished[0]).call
      expect(context.lines.join).to eq(<<~'EOM'.indent(0))
        def foo
          def blerg
        end
      EOM

      expect(context.highlight.join).to eq(<<~'EOM'.indent(0))
        def foo
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

      context = BlockNodeContext.new(search.finished[0]).call
      expect(context.lines.join).to eq(<<~'EOM'.indent(0))
        defzfoo
          puts "lol"
        end
      EOM

      expect(context.highlight.join).to eq(<<~'EOM'.indent(0))
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

      context = BlockNodeContext.new(search.finished[0]).call
      expect(context.lines.join).to eq(<<~'EOM'.indent(0))
        def foo
          end # one
        end # two
      EOM

      expect(context.highlight.join).to eq(<<~'EOM'.indent(0))
        end # two
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

      context = BlockNodeContext.new(search.finished[0]).call
      expect(context.lines.join).to eq(<<~'EOM'.indent(2))
        Foo.call
        end # one
      EOM

      expect(context.highlight.join).to eq(<<~'EOM'.indent(2))
        end # one
      EOM

      context = BlockNodeContext.new(search.finished[1]).call
      expect(context.lines.join).to eq(<<~'EOM'.indent(2))
        Bar.call
        end # three
      EOM

      expect(context.highlight.join).to eq(<<~'EOM'.indent(2))
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

      context = BlockNodeContext.new(search.finished[0]).call
      expect(context.lines.join).to eq(<<~'EOM'.indent(0))
        Foo.call
        end # one
      EOM

      expect(context.highlight.join).to eq(<<~'EOM'.indent(0))
        end # one
      EOM
    end

    class BlockNodeContext
      attr_reader :blocks

      def initialize(journey)
        @journey = journey
        @blocks = []
      end

      def call
        node = @journey.node
        @blocks << node

        if node.leaning == :right && node.leaf?
          while @blocks.last.above && @blocks.last.above.leaning == :equal
            @blocks << @blocks.last.above
          end
        end

        if node.leaning == :left && node.leaf?
          while @blocks.last.below && @blocks.last.below.leaning == :equal
            @blocks << @blocks.last.below
          end
        end

        @blocks.sort_by! {|block| block.start_index }
        self
      end

      def highlight
        @journey.node.lines
      end

      def lines
        blocks.flat_map(&:lines).sort_by {|line| line.number }
      end
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

      context = BlockNodeContext.new(search.finished[0]).call
      expect(context.lines.join).to eq(<<~'EOM'.indent(0))
        Foo.call
          def foo
            puts "lol"
            puts "lol"
          end # one
        end # two
      EOM

      expect(context.highlight.join).to eq(<<~'EOM'.indent(0))
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
        def dog
        end

        if true
          puts (
        else
          puts }
        end

        def cat
        end
      EOM

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call
      search = IndentSearch.new(tree: tree).call


      context = BlockNodeContext.new(search.finished[0]).call
      expect(search.finished.join).to eq(<<~'EOM'.indent(2))
          puts (
          puts }
      EOM
    end

    it "smaller rexe input_modes" do
      source = <<~'EOM'
        class Lookups
          def input_modes
            @input_modes ||= {
                'l' => :line,
                'e' => :enumerator,
                'b' => :one_big_string,
                'n' => :none
            }
          # missing end problem here


          def input_formats
            @input_formats ||=  {
                'j' => :json,
                'm' => :marshal,
                'n' => :none,
                'y' => :yaml,
            }
          end


          def input_parsers
            @input_parsers ||= {
                json:    ->(string)  { JSON.parse(string) },
                marshal: ->(string)  { Marshal.load(string) },
                none:    ->(string)  { string },
                yaml:    ->(string)  { YAML.load(string) },
            }
          end


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
        end



        class CommandLineParser

          include Helpers

          attr_reader :lookups, :options

          def initialize
            @lookups = Lookups.new
            @options = Options.new
          end


          # Inserts contents of REXE_OPTIONS environment variable at the beginning of ARGV.
          private def prepend_environment_options
            env_opt_string = ENV['REXE_OPTIONS']
            if env_opt_string
              args_to_prepend = Shellwords.shellsplit(env_opt_string)
              ARGV.unshift(args_to_prepend).flatten!
            end
          end


          private def add_format_requires_to_requires_list
            formats = [options.input_format, options.output_format, options.log_format]
            requires = formats.map { |format| lookups.format_requires[format] }.uniq.compact
            requires.each { |r| options.requires << r }
          end


          private def help_text
            unless @help_text
              @help_text ||= <<~HEREDOC

                rexe -- Ruby Command Line Executor/Filter -- v#{VERSION} -- #{PROJECT_URL}

                Executes Ruby code on the command line,
                optionally automating management of standard input and standard output,
                and optionally parsing input and formatting output with YAML, JSON, etc.

                rexe [options] [Ruby source code]

                Options:

                -c  --clear_options        Clear all previous command line options specified up to now
                -f  --input_file           Use this file instead of stdin for preprocessed input;
                                          if filespec has a YAML and JSON file extension,
                                          sets input format accordingly and sets input mode to -mb
                -g  --log_format FORMAT    Log format, logs to stderr, defaults to -gn (none)
                                          (see -o for format options)
                -h, --help                 Print help and exit
                -i, --input_format FORMAT  Input format, defaults to -in (None)
                                            -ij  JSON
                                            -im  Marshal
                                            -in  None (default)
                                            -iy  YAML
                -l, --load RUBY_FILE(S)    Ruby file(s) to load, comma separated;
                                            ! to clear all, or precede a name with '-' to remove
                -m, --input_mode MODE      Input preprocessing mode (determines what `self` will be)
                                          defaults to -mn (none)
                                            -ml  line; each line is ingested as a separate string
                                            -me  enumerator (each_line on STDIN or File)
                                            -mb  big string; all lines combined into one string
                                            -mn  none (default); no input preprocessing;
                                                  self is an Object.new
                -n, --[no-]noop            Do not execute the code (useful with -g);
                                          For true: yes, true, y, +; for false: no, false, n
                -o, --output_format FORMAT Output format, defaults to -on (no output):
                                            -oa  Amazing Print
                                            -oi  Inspect
                                            -oj  JSON
                                            -oJ  Pretty JSON
                                            -om  Marshal
                                            -on  No Output (default)
                                            -op  Puts
                                            -oP  Pretty Print
                                            -os  to_s
                                            -oy  YAML
                                            If 2 letters are provided, 1st is for tty devices, 2nd for block
                --project-url              Outputs project URL on Github, then exits
                -r, --require REQUIRE(S)   Gems and built-in libraries to require, comma separated;
                                            ! to clear all, or precede a name with '-' to remove
                -v, --version              Prints version and exits

                ---------------------------------------------------------------------------------------

                In many cases you will need to enclose your source code in single or double quotes.

                If source code is not specified, it will default to 'self',
                which is most likely useful only in a filter mode (-ml, -me, -mb).

                If there is a .rexerc file in your home directory, it will be run as Ruby code
                before processing the input.

                If there is a REXE_OPTIONS environment variable, its content will be prepended
                to the command line so that you can specify options implicitly
                (e.g. `export REXE_OPTIONS="-r amazing_print,yaml"`)

            HEREDOC

              @help_text.freeze
            end

            @help_text
          end


          # File file input mode; detects the input mode (JSON, YAML, or None) from the extension.
          private def autodetect_file_format(filespec)
            extension = File.extname(filespec).downcase
            if extension == '.json'
              :json
            elsif extension == '.yml' || extension == '.yaml'
              :yaml
            else
              :none
            end
          end


          private def open_resource(resource_identifier)
            command = case (`uname`.chomp)
                      when 'Darwin'
                        'open'
                      when 'Linux'
                        'xdg-open'
                      else
                        'start'
                      end

            `#{command} #{resource_identifier}`
          end


        # Using 'optparse', parses the command line.
          # Settings go into this instance's properties (see Struct declaration).
          def parse

            prepend_environment_options

            OptionParser.new do |parser|

              parser.on('-c', '--clear_options', "Clear all previous command line options") do |v|
                options.clear
              end

              parser.on('-f', '--input_file FILESPEC',
                  'Use this file instead of stdin; autodetects YAML and JSON file extensions') do |v|
                unless File.exist?(v)
                  raise "File #{v} does not exist."
                end
                options.input_filespec = v
                options.input_format = autodetect_file_format(v)
                if [:json, :yaml].include?(options.input_format)
                  options.input_mode = :one_big_string
                end
              end

              parser.on('-g', '--log_format FORMAT', 'Log format, logs to stderr, defaults to none (see -o for format options)') do |v|
                options.log_format = lookups.output_formats[v]
                if options.log_format.nil?
                  raise("Output mode was '#{v}' but must be one of #{lookups.output_formats.keys}.")
                end
              end

              parser.on("-h", "--help", "Show help") do |_help_requested|
                puts help_text
                exit
              end

              parser.on('-i', '--input_format FORMAT',
                        'Mode with which to parse input values (n = none (default), j = JSON, m = Marshal, y = YAML') do |v|

                options.input_format = lookups.input_formats[v]
                if options.input_format.nil?
                  raise("Input mode was '#{v}' but must be one of #{lookups.input_formats.keys}.")
                end
              end

              parser.on('-l', '--load RUBY_FILE(S)', 'Ruby file(s) to load, comma separated, or ! to clear') do |v|
                if v == '!'
                  options.loads.clear
                else
                  loadfiles = v.split(',').map(&:strip).map { |s| File.expand_path(s) }
                  removes, adds = loadfiles.partition { |filespec| filespec[0] == '-' }

                  existent, nonexistent = adds.partition { |filespec| File.exists?(filespec) }
                  if nonexistent.any?
                    raise("\nDid not find the following files to load: #{nonexistent}\n\n")
                  else
                    existent.each { |filespec| options.loads << filespec }
                  end

                  removes.each { |filespec| options.loads -= [filespec[1..-1]] }
                end
              end

              parser.on('-m', '--input_mode MODE',
                        'Mode with which to handle input (-ml, -me, -mb, -mn (default)') do |v|

                options.input_mode = lookups.input_modes[v]
                if options.input_mode.nil?
                  raise("Input mode was '#{v}' but must be one of #{lookups.input_modes.keys}.")
                end
              end

              # See https://stackoverflow.com/questions/54576873/ruby-optionparser-short-code-for-boolean-option
              # for an excellent explanation of this optparse incantation.
              # According to the answer, valid options are:
              # -n no, -n yes, -n false, -n true, -n n, -n y, -n +, but not -n -.
              parser.on('-n', '--[no-]noop [FLAG]', TrueClass, "Do not execute the code (useful with -g)") do |v|
                options.noop = (v.nil? ? true : v)
              end

              parser.on('-o', '--output_format FORMAT',
                        'Mode with which to format values for output (`-o` + [aijJmnpsy])') do |v|
                options.output_format_tty   = lookups.output_formats[v[0]]
                options.output_format_block = lookups.output_formats[v[-1]]
                options.output_format = ($stdout.tty? ? options.output_format_tty : options.output_format_block)
                if [options.output_format_tty, options.output_format_block].include?(nil)
                  raise("Bad output mode '#{v}'; each must be one of #{lookups.output_formats.keys}.")
                end
              end

              parser.on('-r', '--require REQUIRE(S)',
                        'Gems and built-in libraries (e.g. shellwords, yaml) to require, comma separated, or ! to clear') do |v|
                if v == '!'
                  options.requires.clear
                else
                  v.split(',').map(&:strip).each do |r|
                    if r[0] == '-'
                      options.requires -= [r[1..-1]]
                    else
                      options.requires << r
                    end
                  end
                end
              end

              parser.on('-v', '--version', 'Print version') do
                puts VERSION
                exit(0)
              end

              # Undocumented feature: open Github project with default web browser on a Mac
              parser.on('', '--open-project') do
                open_resource(PROJECT_URL)
                exit(0)
              end

              parser.on('', '--project-url') do
                puts PROJECT_URL
                exit(0)
              end

            end.parse!

            # We want to do this after all options have been processed because we don't want any clearing of the
            # options (by '-c', etc.) to result in exclusion of these needed requires.
            add_format_requires_to_requires_list

            options.requires = options.requires.sort.uniq
            options.loads.uniq!

            options

          end
        end


        class Main

          include Helpers

          attr_reader :callable, :input_parser, :lookups,
                      :options, :output_formatter,
                      :log_formatter, :start_time, :user_source_code


          def initialize
            @lookups = Lookups.new
            @start_time = DateTime.now
          end


          private def load_global_config_if_exists
            filespec = File.join(Dir.home, '.rexerc')
            load(filespec) if File.exists?(filespec)
          end


          private def init_parser_and_formatters
            @input_parser     = lookups.input_parsers[options.input_format]
            @output_formatter = lookups.formatters[options.output_format]
            @log_formatter    = lookups.formatters[options.log_format]
          end


          # Executes the user specified code in the manner appropriate to the input mode.
          # Performs any optionally specified parsing on input and formatting on output.
          private def execute(eval_context_object, code)
            if options.input_format != :none && options.input_mode != :none
              eval_context_object = input_parser.(eval_context_object)
            end

            value = eval_context_object.instance_eval(&code)

            unless options.output_format == :none
              print output_formatter.(value)
            end
          rescue Errno::EPIPE
            exit(-13)
          end


          # The global $RC (Rexe Context) OpenStruct is available in your user code.
          # In order to make it possible to access this object in your loaded files, we are not creating
          # it here; instead we add properties to it. This way, you can initialize an OpenStruct yourself
          # in your loaded code and it will still work. If you do that, beware, any properties you add will be
          # included in the log output. If the to_s of your added objects is large, that might be a pain.
          private def init_rexe_context
            $RC ||= OpenStruct.new
            $RC.count         = 0
            $RC.rexe_version  = VERSION
            $RC.start_time    = start_time.iso8601
            $RC.source_code   = user_source_code
            $RC.options       = options.to_h

            def $RC.i; count end  # `i` aliases `count` so you can more concisely get the count in your user code
          end


          private def create_callable
            eval("Proc.new { #{user_source_code} }")
          end


          private def lookup_action(mode)
            input = options.input_filespec ? File.open(options.input_filespec) : STDIN
            {
                line:           -> { input.each { |l| execute(l.chomp, callable);            $RC.count += 1 } },
                enumerator:     -> { execute(input.each_line, callable);                     $RC.count += 1 },
                one_big_string: -> { big_string = input.read; execute(big_string, callable); $RC.count += 1 },
                none:           -> { execute(Object.new, callable) }
            }.fetch(mode)
          end


          private def output_log_entry
            if options.log_format != :none
              $RC.duration_secs = Time.now - start_time.to_time
              STDERR.puts(log_formatter.($RC.to_h))
            end
          end


          # Bypasses Bundler's restriction on loading gems
          # (see https://stackoverflow.com/questions/55144094/bundler-doesnt-permit-using-gems-in-project-home-directory)
          private def require!(the_require)
            begin
              require the_require
            rescue LoadError => error
              gem_path = `gem which #{the_require}`
              if gem_path.chomp.strip.empty?
                raise error # re-raise the error, can't fix it
              else
                load_dir = File.dirname(gem_path)
                $LOAD_PATH += load_dir
                require the_require
              end
            end
          end


          # This class' entry point.
          def call

            try do

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
            end
          end
        end
      EOM

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call
      search = IndentSearch.new(tree: tree).call

      expect(search.finished.first.node.to_s).to eq(<<~'EOM'.indent(2))
        def input_modes
      EOM
    end

    it "handles heredocs indentation building microcase outside missing end" do
      source = <<~'EOM'
        parser.on('-c', '--clear_options', "Clear all previous command line options") do |v|
          options.clear

        parser.on('-f', '--input_file FILESPEC',
            'Use this file instead of stdin; autodetects YAML and JSON file extensions') do |v|
          unless File.exist?(v)
            raise "File #{v} does not exist."
          end
          options.input_filespec = v
          options.input_format = autodetect_file_format(v)
          if [:json, :yaml].include?(options.input_format)
            options.input_mode = :one_big_string
          end
        end
      EOM

      code_lines = CleanDocument.new(source: source).call.lines
      document = BlockDocument.new(code_lines: code_lines).call
      tree = IndentTree.new(document: document).call
      search = IndentSearch.new(tree: tree).call

      expect(search.finished.first.node.to_s).to eq(<<~'EOM'.indent(0))
        parser.on('-c', '--clear_options', "Clear all previous command line options") do |v|
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
      tree = IndentTree.new(document: document).call
      search = IndentSearch.new(tree: tree).call

      context = BlockNodeContext.new(search.finished[0]).call
      expect(context.highlight.join).to eq(<<~'EOM'.indent(2))
        end # three
      EOM

      # expect(context.lines.join).to eq(<<~'EOM'.indent(0))
      #  def input_modes
      #    @input_modes ||= {
      #        'l' => :line,
      #        'e' => :enumerator,
      #        'b' => :one_big_string,
      #        'n' => :none
      #    }
      # EOM
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

      context = BlockNodeContext.new(search.finished[0]).call
      expect(context.highlight.join).to eq(<<~'EOM'.indent(4))
        def input_modes
      EOM

      # expect(context.lines.join).to eq(<<~'EOM'.indent(0))
      #  def input_modes
      #    @input_modes ||= {
      #        'l' => :line,
      #        'e' => :enumerator,
      #        'b' => :one_big_string,
      #        'n' => :none
      #    }
      # EOM
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

      expect(search.finished.join).to include(<<~'EOM'.indent(6))
        bundle_path: "vendor/bundle", }
      EOM

      expect(search.finished.join).to eq(<<~'EOM'.indent(6))
        ruby_layer_path: File.expand_path("."),
        gem_layer_path: File.expand_path("."),
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

      expect(search.finished.join).to eq(<<~'EOM')
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
