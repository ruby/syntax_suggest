module SyntaxErrorSearch
  # This class is responsible for generating, storing, and sorting code blocks
  class CodeFrontier
    def initialize(code_lines: )
      @code_lines = code_lines
      @frontier = []
      @indent_hash = {}
      code_lines.each do |line|
        next if line.empty?

        @indent_hash[line.indent] ||= []
        @indent_hash[line.indent] << line
      end
    end

    # Returns true if the document is valid with all lines
    # removed. By default it checks all blocks in present in
    # the frontier array, but can be used for arbitrary arrays
    # of codeblocks as well
    def holds_all_syntax_errors?(block_array = @frontier)
      lines = @code_lines
      block_array.each do |block|
        lines -= block.lines
      end

      return true if lines.empty?

      CodeBlock.new(
        code_lines: @code_lines,
        lines: lines
      ).valid?
    end

    # Returns a code block with the largest indentation possible
    def pop
      return nil if empty?

      self << next_block unless @indent_hash.empty?

      return @frontier.pop
    end

    def next_block
      indent = @indent_hash.keys.sort.last
      lines = @indent_hash[indent].first

      CodeBlock.new(
        lines: lines,
        code_lines: @code_lines
      ).expand_until_neighbors
    end

    # This method is responsible for determining if a new code
    # block should be generated instead of evaluating an already
    # existing block in the frontier
    def generate_new_block?
      return false if @indent_hash.empty?
      return true if @frontier.empty?

      @frontier.last.current_indent <= @indent_hash.keys.sort.last
    end

    # Add a block to the frontier
    #
    # This method ensures the frontier always remains sorted (in indentation order)
    # and that each code block's lines are removed from the indentation hash so we
    # don't re-evaluate the same line multiple times.
    def <<(block)
      block.lines.each do |line|
        @indent_hash[line.indent]&.delete(line)
      end
      @indent_hash.select! {|k, v| !v.empty?}

      @frontier << block
      @frontier.sort!

      self
    end

    def any?
      !empty?
    end

    def empty?
      @frontier.empty? && @indent_hash.empty?
    end

    # Example:
    #
    #   combination([:a, :b, :c, :d])
    #   # => [[:a], [:b], [:c], [:d], [:a, :b], [:a, :c], [:a, :d], [:b, :c], [:b, :d], [:c, :d], [:a, :b, :c], [:a, :b, :d], [:a, :c, :d], [:b, :c, :d], [:a, :b, :c, :d]]
    def self.combination(array)
      guesses = []
      1.upto(array.length).each do |size|
        guesses.concat(array.combination(size).to_a)
      end
      guesses
    end

    # Given that we know our syntax error exists somewhere in our frontier, we want to find
    # the smallest possible set of blocks that contain all the syntax errors
    def detect_invalid_blocks
      self.class.combination(@frontier).detect do |block_array|
        holds_all_syntax_errors?(block_array)
      end || []
    end
  end
end
