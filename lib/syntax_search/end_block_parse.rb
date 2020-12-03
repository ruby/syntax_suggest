# frozen_string_literal: true

module SyntaxErrorSearch
  class LexAll
    def self.call(source:)
      lex = Ripper.lex(source)
      lineno = lex.last&.first&.first + 1
      source_lines = source.lines
      last_lineno = source_lines.count

      until lineno >= last_lineno
        lines = source_lines[lineno..-1]

        lex.concat(Ripper.lex(lines.join, '-', lineno + 1))
        lineno = lex.last&.first&.first + 1
      end

      lex
    end
  end

  class EndBlockParse
    private; attr_reader :code_lines, :lex; public


    def initialize(source:, code_lines: )
      @code_lines = code_lines
      @lex = LexAll.call(source: source)
      lines = []
      @lex.each do |(line, col), event, event_name, *_|
        if event_name == "end" && event == :on_kw
          lines << code_lines[line - 1]
        end
      end

      @end_indent_hash = {}
      lines.each do |line|
        next if line.empty?

        @end_indent_hash[line.indent] ||= []
        @end_indent_hash[line.indent] << line
      end
    end

    def pop
      line = @end_indent_hash[largest_indent].shift
      @end_indent_hash.select! {|k, v| !v.empty?}

      neighbors = neighbors(line)
      inner_neighbors = inner_neighbors(line)

      if CodeBlock.new(lines: inner_neighbors).invalid_end?
        before_line = (neighbors - inner_neighbors).last(2).first
        lines = [before_line, inner_neighbors, line].flatten.compact
        neighbors = neighbors - lines
      else
        lines = [neighbors.pop]
      end

      while (block = CodeBlock.new(lines: lines)) && block.invalid? && neighbors.any?
        lines.prepend neighbors.pop
      end

      return block
    end

    def inner_neighbors(line)
      scan = AroundBlockScan.new(code_lines: code_lines, block: CodeBlock.new(lines: line))
        .skip(:empty?)
        .skip(:hidden?)
        .scan_while {|l| l.indent > line.indent }

      @code_lines[scan.before_index...line.index]
    end

    def neighbors(line)
      scan = AroundBlockScan.new(code_lines: code_lines, block: CodeBlock.new(lines: line))
        .skip(:empty?)
        .skip(:hidden?)
        .scan_while {|l| l.indent >= line.indent }

      @code_lines[scan.before_index..line.index]
    end

    private def largest_indent
      @end_indent_hash.keys.sort.last
    end
  end
end
