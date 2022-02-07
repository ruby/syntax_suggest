# frozen_string_literal: true

module DeadEnd
  # Records a BlockNode to a folder on disk
  #
  # This class allows for tracing the algorithm
  class BlockRecorder

    # Convienece constructor for building a BlockRecorder given
    # a directory object.
    #
    # When nil and debug env vars have not been triggered, a
    # NullRecorder instance will be returned
    #
    # Multiple different processes may be logging to the same
    # directory, so writing to a subdir is recommended
    def self.from_dir(dir, subdir: , code_lines: )
      if dir == DEFAULT_VALUE
        dir = ENV["DEAD_END_RECORD_DIR"] || ENV["DEBUG"] ? DeadEnd.record_dir("tmp") : nil
      end

      if dir.nil?
        NullRecorder.new
      else
        dir = Pathname(dir)
        dir = dir.join(subdir)
        dir.mkpath
        BlockRecorder.new(dir: dir, code_lines: code_lines)
      end
    end

    def initialize(dir:, code_lines:)
      @code_lines = code_lines
      @dir = Pathname(dir)
      @tick = 0
      @name_tick = Hash.new { |h, k| h[k] = 0 }
    end

    def capture(block, name:)
      @tick += 1

      filename = "#{@tick}-#{name}-#{@name_tick[name] += 1}-(#{block.starts_at}__#{block.ends_at}).txt"
      @dir.join(filename).open(mode: "a") do |f|
        document = DisplayCodeWithLineNumbers.new(
          lines: @code_lines,
          terminal: false,
          highlight_lines: block.lines
        ).call

        f.write("    Block lines: #{(block.starts_at + 1)..(block.ends_at + 1)} (#{name})\n")
        f.write("    indent: #{block.indent} next_indent: #{block.next_indent}\n\n")
        f.write(document.to_s)
      end
    end
  end

  # Used when recording isn't needed
  class NullRecorder
    def capture(block, name:)
    end
  end
end
