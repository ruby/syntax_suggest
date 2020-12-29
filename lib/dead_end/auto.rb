# frozen_string_literal: true
#
require_relative "../dead_end/internals"

# Monkey patch kernel to ensure that all `require` calls call the same
# method
module Kernel
  alias_method :original_require, :require
  alias_method :original_require_relative, :require_relative
  alias_method :original_load, :load

  def load(file, wrap = false)
    original_load(file)
  rescue SyntaxError => e
    DeadEnd.handle_error(e)
  end

  def require(file)
    original_require(file)
  rescue SyntaxError => e
    DeadEnd.handle_error(e)
  end

  def require_relative(file)
    if Pathname.new(file).absolute?
      original_require file
    else
      original_require File.expand_path("../#{file}", caller_locations(1, 1)[0].absolute_path)
    end
  rescue SyntaxError => e
    DeadEnd.handle_error(e)
  end
end

# I honestly have no idea why this Object delegation is needed
# I keep staring at bootsnap and it doesn't have to do this
# is there a bug in their implementation they haven't caught or
# am I doing something different?
class Object
  private
  def load(path, wrap = false)
    Kernel.load(path, wrap)
  rescue SyntaxError => e
    DeadEnd.handle_error(e)
  end

  def require(path)
    Kernel.require(path)
  rescue SyntaxError => e
    DeadEnd.handle_error(e)
  end
end

module DeadEnd
  IsProduction = -> {
    ENV["RAILS_ENV"] == "production" || ENV["RACK_ENV"] == "production"
  }
end

# Unlike a syntax error, a NoMethodError can occur hundreds or thousands of times and
# chew up CPU and other resources. Since this is primarilly a "development" optimization
# we can attempt to disable this behavior in a production context.
if !DeadEnd::IsProduction.call
  class NoMethodError
    def to_s
      return super if DeadEnd::IsProduction.call

      file, line, _ = backtrace[0].split(":")
      return super if !File.exist?(file)

      index = line.to_i - 1
      source = File.read(file)
      code_lines = DeadEnd::CodeLine.parse(source)

      block = DeadEnd::CodeBlock.new(lines: code_lines[index])
      lines = DeadEnd::CaptureCodeContext.new(
        blocks: block,
        code_lines: code_lines
      ).call

      message = super.dup
      message << $/
      message << $/

      message << DeadEnd::DisplayCodeWithLineNumbers.new(
        lines: lines,
        highlight_lines: block.lines,
        terminal: self.class.to_tty?
      ).call

      message << $/
      message
    rescue => e
      puts "DeadEnd Internal error: #{e.message}"
      puts "DeadEnd Internal backtrace: #{e.backtrace}"
      super
    end
  end
end
