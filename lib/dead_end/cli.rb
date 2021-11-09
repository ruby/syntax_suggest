# frozen_string_literal: true

require "pathname"
require "optparse"

module DeadEnd
  # All the logic of the exe/dead_end CLI in one handy spot
  #
  #   Cli.new(argv: ["--help"]).call
  #   Cli.new(argv: ["<path/to/file>.rb"]).call
  #   Cli.new(argv: ["<path/to/file>.rb", "--record=tmp"]).call
  #   Cli.new(argv: ["<path/to/file>.rb", "--terminal"]).call
  #
  class Cli
    attr_accessor :options

    # ARGV is Everything passed to the executable, does not include executable name
    #
    # All other intputs are dependency injection for testing
    def initialize(argv:, exit_obj: Kernel, io: $stdout, env: ENV)
      @options = {}
      @parser = nil
      options[:record_dir] = env["DEAD_END_RECORD_DIR"]
      options[:record_dir] = "tmp" if env["DEBUG"]
      options[:terminal] = DeadEnd::DEFAULT_VALUE

      @io = io
      @argv = argv
      @exit_obj = exit_obj
    end

    def call
      if @argv.empty?
        # Display help if raw command
        parser.parse! %w[--help]
        return
      else
        # Mutates @argv
        parse
        return if options[:exit]
      end

      if @argv.empty?
        @io.puts "No file given"
        @exit_obj.exit(1)
        return
      end

      display_array = []
      while (file_name = @argv.pop)
        file = Pathname(file_name)
        if !file.exist?
          @io.puts "file not found: #{file.expand_path} "
          @exit_obj.exit(1)
          return
        end

        @io.puts "Record dir: #{options[:record_dir]}" if options[:record_dir]

        display_array << DeadEnd.call(
          io: @io,
          source: file.read,
          filename: file.expand_path,
          terminal: options.fetch(:terminal, DeadEnd::DEFAULT_VALUE),
          record_dir: options[:record_dir]
        )
      end

      if display_array.empty? || display_array.detect { |d| !d.document_ok? }
        @exit_obj.exit(1)
      else
        @exit_obj.exit(0)
      end
    end

    def parse
      parser.parse!(@argv)

      self
    end

    def parser
      @parser ||= OptionParser.new do |opts|
        opts.banner = <<~EOM
          Usage: dead_end <file> [options]

          Parses a ruby source file and searches for syntax error(s) such as
          unexpected `end', expecting end-of-input.

          Example:

            $ dead_end dog.rb

            # ...

              ❯ 10  defdog
              ❯ 15  end

          ENV options:

            DEAD_END_RECORD_DIR=<dir>

            Records the steps used to search for a syntax error
            to the given directory

          Options:
        EOM

        opts.version = DeadEnd::VERSION

        opts.on("--help", "Help - displays this message") do |v|
          @io.puts opts
          options[:exit] = true
          @exit_obj.exit
        end

        opts.on("--record <dir>", "Records the steps used to search for a syntax error to the given directory") do |v|
          options[:record_dir] = v
        end

        opts.on("--terminal", "Enable terminal highlighting") do |v|
          options[:terminal] = true
        end

        opts.on("--no-terminal", "Disable terminal highlighting") do |v|
          options[:terminal] = false
        end
      end
    end
  end
end
