# frozen_string_literal: true

module DeadEnd
  # Sort elements on insert
  #
  # Instead of constantly calling `sort!`, put
  # the element where it belongs the first time
  # around
  #
  # Example:
  #
  #   sorted = InsertionSort.new
  #   sorted << 33
  #   sorted << 44
  #   sorted << 1
  #   puts sorted.to_a
  #   # => [1, 44, 33]
  #
  class InsertionSort
    def initialize
      @array = []
    end

    def <<(value)
      insert_in = @array.length
      @array.each.with_index do |existing, index|
        case value <=> existing
        when -1
          insert_in = index
          break
        when 0
          insert_in = index
          break
        when 1
          # Keep going
        end
      end

      @array.insert(insert_in, value)
    end

    def to_a
      @array
    end
  end
end
