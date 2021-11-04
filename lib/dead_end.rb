# frozen_string_literal: true

require_relative "dead_end/version"

require "tmpdir"
require "stringio"
require "pathname"
require "ripper"
require "timeout"

module DeadEnd
  # Used to indicate a default value that cannot
  # be confused with another input
  DEFAULT_VALUE = Object.new.freeze

  class Error < StandardError; end
  TIMEOUT_DEFAULT = ENV.fetch("DEAD_END_TIMEOUT", 1).to_i

  def self.handle_error(e)
    filename = e.message.split(":").first
    $stderr.sync = true

    call(
      source: Pathname(filename).read,
      filename: filename
    )

    raise e
  end

  def self.record_dir(dir)
    time = Time.now.strftime("%Y-%m-%d-%H-%M-%s-%N")
    dir = Pathname(dir)
    symlink = dir.join("last").tap { |path| path.delete if path.exist? }
    dir.join(time).tap { |path|
      path.mkpath
      FileUtils.symlink(path.basename, symlink)
    }
  end

  def self.call(source:, filename: DEFAULT_VALUE, terminal: DEFAULT_VALUE, record_dir: nil, timeout: TIMEOUT_DEFAULT, io: $stderr)
    search = nil
    filename = nil if filename == DEFAULT_VALUE
    Timeout.timeout(timeout) do
      record_dir ||= ENV["DEBUG"] ? "tmp" : nil
      search = CodeSearch.new(source, record_dir: record_dir).call
    end

    blocks = search.invalid_blocks
    DisplayInvalidBlocks.new(
      io: io,
      blocks: blocks,
      filename: filename,
      terminal: terminal,
      code_lines: search.code_lines
    ).call
  rescue Timeout::Error => e
    io.puts "Search timed out DEAD_END_TIMEOUT=#{timeout}, run with DEBUG=1 for more info"
    io.puts e.backtrace.first(3).join($/)
  end

  # Used for counting spaces
  module SpaceCount
    def self.indent(string)
      string.split(/\S/).first&.length || 0
    end
  end

  # This will tell you if the `code_lines` would be valid
  # if you removed the `without_lines`. In short it's a
  # way to detect if we've found the lines with syntax errors
  # in our document yet.
  #
  #   code_lines = [
  #     CodeLine.new(line: "def foo\n",   index: 0)
  #     CodeLine.new(line: "  def bar\n", index: 1)
  #     CodeLine.new(line: "end\n",       index: 2)
  #   ]
  #
  #   DeadEnd.valid_without?(
  #     without_lines: code_lines[1],
  #     code_lines: code_lines
  #   )                                    # => true
  #
  #   DeadEnd.valid?(code_lines) # => false
  def self.valid_without?(without_lines:, code_lines:)
    lines = code_lines - Array(without_lines).flatten

    if lines.empty?
      true
    else
      valid?(lines)
    end
  end

  def self.invalid?(source)
    source = source.join if source.is_a?(Array)
    source = source.to_s

    Ripper.new(source).tap(&:parse).error?
  end

  # Returns truthy if a given input source is valid syntax
  #
  #   DeadEnd.valid?(<<~EOM) # => true
  #     def foo
  #     end
  #   EOM
  #
  #   DeadEnd.valid?(<<~EOM) # => false
  #     def foo
  #       def bar # Syntax error here
  #     end
  #   EOM
  #
  # You can also pass in an array of lines and they'll be
  # joined before evaluating
  #
  #   DeadEnd.valid?(
  #     [
  #       "def foo\n",
  #       "end\n"
  #     ]
  #   ) # => true
  #
  #   DeadEnd.valid?(
  #     [
  #       "def foo\n",
  #       "  def bar\n", # Syntax error here
  #       "end\n"
  #     ]
  #   ) # => false
  #
  # As an FYI the CodeLine class instances respond to `to_s`
  # so passing a CodeLine in as an object or as an array
  # will convert it to it's code representation.
  def self.valid?(source)
    !invalid?(source)
  end
end

require_relative "dead_end/code_line"
require_relative "dead_end/code_block"
require_relative "dead_end/code_search"
require_relative "dead_end/code_frontier"
require_relative "dead_end/clean_document"

require_relative "dead_end/lex_all"
require_relative "dead_end/block_expand"
require_relative "dead_end/insertion_sort"
require_relative "dead_end/around_block_scan"
require_relative "dead_end/ripper_errors"
require_relative "dead_end/display_invalid_blocks"
require_relative "dead_end/parse_blocks_from_indent_line"

require_relative "dead_end/explain_syntax"

require_relative "dead_end/auto"
require_relative "dead_end/cli"
