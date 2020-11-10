require_relative "../syntax_search"

require_relative "auto.rb"

SyntaxErrorSearch.send(:remove_const, :SEARCH_SOURCE_ON_ERROR_DEFAULT)
SyntaxErrorSearch::SEARCH_SOURCE_ON_ERROR_DEFAULT = false

