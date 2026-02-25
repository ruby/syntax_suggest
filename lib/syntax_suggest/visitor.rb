module SyntaxSuggest
  # A visitor that walks the AST and pulls out information
  # that is too dificult to discern by just looking at tokens
  class Visitor < Prism::Visitor
    attr_reader :endless_def_keyword_locs

    def initialize
      @endless_def_keyword_locs = []
      @consecutive_lines = {}
    end

    def consecutive_lines
      @consecutive_lines.keys.sort
    end

    # Record lines where a method call is logically connected
    # to subsequent lines. This is the case when a method call
    # is broken up by a newline
    def visit_call_node(node)
      receiver_loc = node.receiver&.location
      call_operator_loc = node.call_operator_loc
      message_loc = node.message_loc
      if receiver_loc && call_operator_loc && message_loc
        # foo
        #   .bar
        if receiver_loc.end_line != call_operator_loc.start_line && call_operator_loc.start_line == message_loc.start_line
          (receiver_loc.end_line..call_operator_loc.start_line - 1).each do |line|
            @consecutive_lines[line] = true
          end
        end

        # foo.
        #   bar
        if receiver_loc.end_line == call_operator_loc.start_line && call_operator_loc.start_line != message_loc.start_line
          (call_operator_loc.start_line..message_loc.start_line - 1).each do |line|
            @consecutive_lines[line] = true
          end
        end
      end
      super
    end

    # Endless method definitions like `def foo = 123` are valid without
    # an `end` keyword. We record their keyword here so that we can later
    # skip considering them for keywords since they have no coresponding
    # end
    def visit_def_node(node)
      @endless_def_keyword_locs << node.def_keyword_loc if node.equal_loc
      super
    end
  end
end
