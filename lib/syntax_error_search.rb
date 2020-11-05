require "syntax_error_search/version"

require 'parser/current'
require 'tmpdir'
require 'pathname'

module SyntaxErrorSearch
  class Error < StandardError; end

  # Used for counting spaces
  module SpaceCount
    def self.indent(string)
      string.split(/\w/).first&.length || 0
    end
  end


  def self.valid?(source)
    source = source.join if source.is_a?(Array)
    source = source.to_s

    # Parser writes to stderr even if you catch the error
    #
    stderr = $stderr
    $stderr = StringIO.new

    Parser::CurrentRuby.parse(source)
    true
  rescue Parser::SyntaxError
    false
  ensure
    $stderr = stderr if stderr
  end
end

require_relative "syntax_error_search/code_line"
require_relative "syntax_error_search/code_block"
require_relative "syntax_error_search/code_frontier"
require_relative "syntax_error_search/code_search"
