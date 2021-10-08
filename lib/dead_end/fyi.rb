require_relative "../dead_end/internals"

require_relative "auto"

DeadEnd.send(:remove_const, :SEARCH_SOURCE_ON_ERROR_DEFAULT)
DeadEnd::SEARCH_SOURCE_ON_ERROR_DEFAULT = false

warn "DEPRECATED: calling `require 'dead_end/fyi'` is deprecated, `require 'dead_end'` instead"
