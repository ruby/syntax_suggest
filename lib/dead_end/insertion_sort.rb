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

    def delete(item)
      index = @array.bsearch_index {|i| item <=> i }
      @array.delete_at(index)
    end

    def <<(value)
      insert_in = @array.bsearch_index {|i| i >= value } || @array.length

      @array.insert(insert_in, value)
    end

    def to_a
      @array
    end
  end
end
