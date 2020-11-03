module SyntaxErrorSearch


  # This represents an entire source document
  #
  # Once created
  class CodeSource
    attr_reader :lines, :indent_hash, :code_lines

    def initialize(source)
      @frontier = []
      @lines = source.lines
      @indent_array = []
      @indent_hash = Hash.new {|h, k| h[k] = [] }

      @code_lines = []
      lines.each_with_index do |line, i|
        code_line = CodeLine.new(
          line: line,
          index: i,
        )

        @indent_array[i] = code_line.indent
        @indent_hash[code_line.indent] << code_line
        @code_lines << code_line
      end
      @new_frontier = CodeFrontier.new(code_lines: @code_lines)
    end

    def get_max_indent
      @indent_hash.select! {|k, v| !v.empty?}
      @indent_hash.keys.sort.last
    end

    def indent_hash
      @indent_hash
    end


    def pop_max_indent_line(indent = get_max_indent)
      return nil if @indent_hash.empty?

      if (line = @indent_hash[indent].shift)
        return line
      else
        pop_max_indent_line
      end
    end

    # Returns a CodeBlock based on the maximum indentation
    # present in the source
    def max_indent_to_block
      if (line = pop_max_indent_line)
        block = CodeBlock.new(
          source: self,
          lines: line
        )
        block.expand_until_neighbors
        clean_hash(block)

        return block
      end
    end

    # Returns the highest indentation code block from the
    # frontier or if
    def next_frontier
      if @frontier.any?
        @frontier.sort!
        block = @frontier.pop

        if self.get_max_indent && block.current_indent <= self.get_max_indent
          @frontier.push(block)
          block = nil
        else

          block.expand_until_next_boundry
          clean_hash(block)
          return block
        end
      end

      max_indent_to_block if block.nil?
    end

    def clean_hash(block)
      block.lines.each do |line|
        @indent_hash[line.indent].delete(line)
      end
    end

    def invalid_code
      CodeBlock.new(
       lines: code_lines.select(&:marked_invalid?),
       source: self
      )
    end

    def frontier_holds_syntax_error?
      lines = code_lines
      @frontier.each do |block|
        lines -= block.lines
      end

      return true if lines.empty?

      CodeBlock.new(
        source: self,
        lines: lines
      ).valid?
    end

    def detect_new
      until @new_frontier.holds_all_syntax_errors?
        block = @new_frontier.pop

        if block.valid?
          block.lines.each(&:mark_invisible)

        else
          block.expand_until_neighbors
          @new_frontier << block
        end
      end
      # @new_frontier.detect_bad_blocks
    end

    def detect_invalid
      while block = next_frontier
        if block.valid?
          block.lines.each(&:mark_invisible)
          next
        end

        if block.document_valid_without?
          block.lines.each(&:mark_invalid)
          return
        end

        @frontier << block

        if frontier_holds_syntax_error?
          @frontier.each do |block|
            block.lines.each(&:mark_invalid)
          end
          return
        end
      end
    end
  end
end
