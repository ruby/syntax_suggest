# frozen_string_literal: true

require_relative "../dead_end"

# Monkey patch kernel to ensure that all `require` calls call the same
# method
module Kernel
  module_function

  alias_method :dead_end_original_require, :require
  alias_method :dead_end_original_require_relative, :require_relative
  alias_method :dead_end_original_load, :load

  def load(file, wrap = false)
    dead_end_original_load(file)
  rescue SyntaxError => e
    DeadEnd.handle_error(e)
  end

  def require(file)
    dead_end_original_require(file)
  rescue SyntaxError => e
    DeadEnd.handle_error(e)
  end

  def require_relative(file)
    if Pathname.new(file).absolute?
      dead_end_original_require file
    else
      dead_end_original_require File.expand_path("../#{file}", Kernel.caller_locations(1, 1)[0].absolute_path)
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
