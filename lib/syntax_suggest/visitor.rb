module SyntaxSuggest
  # Walks the Prism AST to extract structural info that cannot be reliably determined from tokens
  # alone.
  #
  # Such as the location of lines that must be logically joined so the search algorithm will
  # treat them as one. Example:
  #
  #   source = <<~RUBY
  #     User                        # 1
  #       .where(name: "Earlopain") # 2
  #       .first                    # 3
  #   RUBY
  #   ast, _tokens = Prism.parse_lex(source).value
  #   visitor = Visitor.new
  #   visitor.visit(ast)
  #   visitor.consecutive_lines_hash # => [1, 2]
  #
  # This output means that line 1 and line 2 needs to be joined with it's next line.
  #
  # And determing the location of "endless" method defintition. For example:
  #
  #   source = <<~RUBY
  #     def square(x) = x * x # 1
  #   RUBY
  #
  #   ast, _tokens = Prism.parse_lex(source).value
  #   visitor = Visitor.new
  #   visitor.endless_def_keyword_locs.first.start_line # => 1
  class Visitor < Prism::Visitor
    attr_reader :endless_def_keyword_locs, :consecutive_lines

    def initialize
      @endless_def_keyword_locs = []
      @consecutive_lines_hash = {}
      @consecutive_lines = []
    end

    def visit(ast)
      super(ast)
      @consecutive_lines = @consecutive_lines_hash.keys.sort
      self
    end

    # Called by Prism::Visitor for every method-call node in the AST
    # (e.g. `foo.bar`, `foo.bar.baz`).
    def visit_call_node(node)
      receiver_loc = node.receiver&.location
      call_operator_loc = node.call_operator_loc
      message_loc = node.message_loc
      if receiver_loc && call_operator_loc && message_loc
        # dot-leading (dot on the next line)
        #   foo        # line 1 — consecutive
        #     .bar     # line 2
        if receiver_loc.end_line != call_operator_loc.start_line && call_operator_loc.start_line == message_loc.start_line
          (receiver_loc.end_line..call_operator_loc.start_line - 1).each do |line|
            @consecutive_lines_hash[line] = true
          end
        end

        # dot-trailing (dot on the same line as the receiver)
        #   foo.       # line 1 — consecutive
        #     bar      # line 2
        if receiver_loc.end_line == call_operator_loc.start_line && call_operator_loc.start_line != message_loc.start_line
          (call_operator_loc.start_line..message_loc.start_line - 1).each do |line|
            @consecutive_lines_hash[line] = true
          end
        end
      end
      super
    end

    # Called by Prism::Visitor for every `def` node in the AST.
    # Records the keyword location for endless method definitions
    # like `def foo = 123`. These are valid without a matching `end`,
    # so Token must exclude them when deciding if a line is a keyword.
    def visit_def_node(node)
      @endless_def_keyword_locs << node.def_keyword_loc if node.equal_loc
      super
    end
  end
end
