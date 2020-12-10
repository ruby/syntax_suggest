require_relative "../dead_end"

require_relative "auto.rb"

DeadEnd.send(:remove_const, :SEARCH_SOURCE_ON_ERROR_DEFAULT)
DeadEnd::SEARCH_SOURCE_ON_ERROR_DEFAULT = false

