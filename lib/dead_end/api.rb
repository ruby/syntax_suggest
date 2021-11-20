require_relative "version"

require "tmpdir"
require "stringio"
require "pathname"
require "ripper"
require "timeout"

module DeadEnd
  # Used to indicate a default value that cannot
  # be confused with another input.
  DEFAULT_VALUE = Object.new.freeze

  class Error < StandardError; end
  TIMEOUT_DEFAULT = ENV.fetch("DEAD_END_TIMEOUT", 1).to_i

  # DeadEnd.handle_error [Public]
  #
  # Takes a `SyntaxError`` exception, uses the
  # error message to locate the file. Then the file
  # will be analyzed to find the location of the syntax
  # error and emit that location to stderr.
  #
  # Example:
  #
  #   begin
  #     require 'bad_file'
  #   rescue => e
  #     DeadEnd.handle_error(e)
  #   end
  #
  # By default it will re-raise the exception unless
  # `re_raise: false`. The message output location
  # can be configured using the `io: $stderr` input.
  #
  # If a valid filename cannot be determined, the original
  # exception will be re-raised (even with
  # `re_raise: false`).
  def self.handle_error(e, re_raise: true, io: $stderr)
    unless e.is_a?(SyntaxError)
      io.puts("DeadEnd: Must pass a SyntaxError, got: #{e.class}")
      raise e
    end

    file = PathnameFromMessage.new(e.message, io: io).call.name
    raise e unless file

    io.sync = true

    call(
      io: io,
      source: file.read,
      filename: file
    )

    raise e if re_raise
  end

  # DeadEnd.call [Private]
  #
  # Main private interface
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

  # DeadEnd.record_dir [Private]
  #
  # Used to generate a unique directory to record
  # search steps for debugging
  def self.record_dir(dir)
    time = Time.now.strftime("%Y-%m-%d-%H-%M-%s-%N")
    dir = Pathname(dir)
    symlink = dir.join("last").tap { |path| path.delete if path.exist? }
    dir.join(time).tap { |path|
      path.mkpath
      FileUtils.symlink(path.basename, symlink)
    }
  end

  # DeadEnd.valid_without? [Private]
  #
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

  # DeadEnd.invalid? [Private]
  #
  # Opposite of `DeadEnd.valid?`
  def self.invalid?(source)
    source = source.join if source.is_a?(Array)
    source = source.to_s

    Ripper.new(source).tap(&:parse).error?
  end

  # DeadEnd.valid? [Private]
  #
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

# Integration
require_relative "cli"

# Core logic
require_relative "code_search"
require_relative "code_frontier"
require_relative "explain_syntax"
require_relative "clean_document"

# Helpers
require_relative "lex_all"
require_relative "code_line"
require_relative "code_block"
require_relative "block_expand"
require_relative "ripper_errors"
require_relative "insertion_sort"
require_relative "around_block_scan"
require_relative "pathname_from_message"
require_relative "display_invalid_blocks"
require_relative "parse_blocks_from_indent_line"
