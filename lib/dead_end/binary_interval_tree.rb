# frozen_string_literal: true

module DeadEnd
  module Containers
  end

  # rdoc
  #     A Deque is a container that allows items to be added and removed from both the front and back,
  #     acting as a combination of a Stack and Queue.
  #
  #     This implementation uses a doubly-linked list, guaranteeing O(1) complexity for all operations.
  class Containers::RubyDeque
    include Enumerable

    Node = Struct.new(:left, :right, :obj)

    # Create a new Deque. Takes an optional array argument to initialize the Deque.
    #
    #   d = Containers::Deque.new([1, 2, 3])
    #   d.front #=> 1
    #   d.back #=> 3
    def initialize(ary = [])
      @front = nil
      @back = nil
      @size = 0
      ary.to_a.each { |obj| push_back(obj) }
    end

    # Returns true if the Deque is empty, false otherwise.
    def empty?
      @size == 0
    end

    # Removes all the objects in the Deque.
    def clear
      @front = @back = nil
      @size = 0
    end

    # Return the number of items in the Deque.
    #
    #   d = Containers::Deque.new([1, 2, 3])
    #   d.size #=> 3
    attr_reader :size
    alias_method :length, :size

    # Returns the object at the front of the Deque but does not remove it.
    #
    #   d = Containers::Deque.new
    #   d.push_front(1)
    #   d.push_front(2)
    #   d.front #=> 2
    def front
      @front && @front.obj
    end

    # Returns the object at the back of the Deque but does not remove it.
    #
    #   d = Containers::Deque.new
    #   d.push_front(1)
    #   d.push_front(2)
    #   d.back #=> 1
    def back
      @back && @back.obj
    end

    # Adds an object at the front of the Deque.
    #
    #   d = Containers::Deque.new([1, 2, 3])
    #   d.push_front(0)
    #   d.pop_front #=> 0
    def push_front(obj)
      node = Node.new(nil, nil, obj)
      if @front
        node.right = @front
        @front.left = node
        @front = node
      else
        @front = @back = node
      end
      @size += 1
      obj
    end

    # Adds an object at the back of the Deque.
    #
    #   d = Containers::Deque.new([1, 2, 3])
    #   d.push_back(4)
    #   d.pop_back #=> 4
    def push_back(obj)
      node = Node.new(nil, nil, obj)
      if @back
        node.left = @back
        @back.right = node
        @back = node
      else
        @front = @back = node
      end
      @size += 1
      obj
    end

    # Returns the object at the front of the Deque and removes it.
    #
    #   d = Containers::Deque.new
    #   d.push_front(1)
    #   d.push_front(2)
    #   d.pop_front #=> 2
    #   d.size #=> 1
    def pop_front
      return nil unless @front
      node = @front
      if @size == 1
        clear
        return node.obj
      else
        @front.right.left = nil
        @front = @front.right
      end
      @size -= 1
      node.obj
    end

    # Returns the object at the back of the Deque and removes it.
    #
    #   d = Containers::Deque.new
    #   d.push_front(1)
    #   d.push_front(2)
    #   d.pop_back #=> 1
    #   d.size #=> 1
    def pop_back
      return nil unless @back
      node = @back
      if @size == 1
        clear
        return node.obj
      else
        @back.left.right = nil
        @back = @back.left
      end
      @size -= 1
      node.obj
    end

    # Iterate over the Deque in FIFO order.
    def each_forward
      return unless @front
      node = @front
      while node
        yield node.obj
        node = node.right
      end
    end
    alias_method :each, :each_forward

    # Iterate over the Deque in LIFO order.
    def each_backward
      return unless @back
      node = @back
      while node
        yield node.obj
        node = node.left
      end
    end
    alias_method :reverse_each, :each_backward
  end
  Containers::Deque = Containers::RubyDeque

  class Containers::Stack
    include Enumerable
    # Create a new stack. Takes an optional array argument to initialize the stack.
    #
    #   s = Containers::Stack.new([1, 2, 3])
    #   s.pop #=> 3
    #   s.pop #=> 2
    def initialize(ary = [])
      @container = Containers::Deque.new(ary)
    end

    # Returns the next item from the stack but does not remove it.
    #
    #   s = Containers::Stack.new([1, 2, 3])
    #   s.next #=> 3
    #   s.size #=> 3
    def next
      @container.back
    end

    # Adds an item to the stack.
    #
    #   s = Containers::Stack.new([1])
    #   s.push(2)
    #   s.pop #=> 2
    #   s.pop #=> 1
    def push(obj)
      @container.push_back(obj)
    end
    alias_method :<<, :push

    # Removes the next item from the stack and returns it.
    #
    #   s = Containers::Stack.new([1, 2, 3])
    #   s.pop #=> 3
    #   s.size #=> 2
    def pop
      @container.pop_back
    end

    # Return the number of items in the stack.
    #
    #   s = Containers::Stack.new([1, 2, 3])
    #   s.size #=> 3
    def size
      @container.size
    end

    # Returns true if the stack is empty, false otherwise.
    def empty?
      @container.empty?
    end

    # Iterate over the Stack in LIFO order.
    def each(&block)
      @container.each_backward(&block)
    end
  end

  # rdoc
  #     A RBTreeMap is a map that is stored in sorted order based on the order of its keys. This ordering is
  #     determined by applying the function <=> to compare the keys. No duplicate values for keys are allowed,
  #     so duplicate values are overwritten.
  #
  #     A major advantage of RBTreeMap over a Hash is the fact that keys are stored in order and can thus be
  #     iterated over in order. This is useful for many datasets.
  #
  #     The implementation is adapted from Robert Sedgewick's Left Leaning Red-Black Tree implementation,
  #     which can be found at http://www.cs.princeton.edu/~rs/talks/LLRB/Java/RedBlackBST.java
  #
  #     Containers::RBTreeMap automatically uses the faster C implementation if it was built
  #     when the gem was installed. Alternatively, Containers::RubyRBTreeMap and Containers::CRBTreeMap can be
  #     explicitly used as well; their functionality is identical.
  #
  #     Most methods have O(log n) complexity.
  #
  class Containers::RubyRBTreeMap
    include Enumerable

    attr_accessor :height_black

    # Create and initialize a new empty TreeMap.
    def initialize(node_klass: Node)
      @root = nil
      @height_black = 0
      @node_klass = node_klass
    end

    # Insert an item with an associated key into the TreeMap, and returns the item inserted
    #
    # Complexity: O(log n)
    #
    # map = Containers::TreeMap.new
    # map.push("MA", "Massachusetts") #=> "Massachusetts"
    # map.get("MA") #=> "Massachusetts"
    def push(key, value)
      @root = insert(@root, key, value)
      @height_black += 1 if isred(@root)
      @root.color = :black
      value
    end
    alias_method :[]=, :push

    # Return the number of items in the TreeMap.
    #
    #   map = Containers::TreeMap.new
    #   map.push("MA", "Massachusetts")
    #   map.push("GA", "Georgia")
    #   map.size #=> 2
    def size
      @root and @root.size or 0
    end

    # Return the height of the tree structure in the TreeMap.
    #
    # Complexity: O(1)
    #
    #   map = Containers::TreeMap.new
    #   map.push("MA", "Massachusetts")
    #   map.push("GA", "Georgia")
    #   map.height #=> 2
    def height
      @root and @root.height or 0
    end

    # Return true if key is found in the TreeMap, false otherwise
    #
    # Complexity: O(log n)
    #
    #   map = Containers::TreeMap.new
    #   map.push("MA", "Massachusetts")
    #   map.push("GA", "Georgia")
    #   map.has_key?("GA") #=> true
    #   map.has_key?("DE") #=> false
    def has_key?(key)
      !get(key).nil?
    end

    # Return the item associated with the key, or nil if none found.
    #
    # Complexity: O(log n)
    #
    #   map = Containers::TreeMap.new
    #   map.push("MA", "Massachusetts")
    #   map.push("GA", "Georgia")
    #   map.get("GA") #=> "Georgia"
    def get(key)
      get_recursive(@root, key)
    end
    alias_method :[], :get

    def get_node_for_key(key)
      get_recursive_node_for_key(@root, key)
    end

    # Return the smallest key in the map.
    #
    # Complexity: O(log n)
    #
    #   map = Containers::TreeMap.new
    #   map.push("MA", "Massachusetts")
    #   map.push("GA", "Georgia")
    #   map.min_key #=> "GA"
    def min_key
      @root.nil? ? nil : min_recursive(@root)
    end

    # Return the largest key in the map.
    #
    # Complexity: O(log n)
    #
    #   map = Containers::TreeMap.new
    #   map.push("MA", "Massachusetts")
    #   map.push("GA", "Georgia")
    #   map.max_key #=> "MA"
    def max_key
      @root.nil? ? nil : max_recursive(@root)
    end

    # Deletes the item and key if it's found, and returns the item. Returns nil
    # if key is not present.
    #
    # !!! Warning !!! There is a currently a bug in the delete method that occurs rarely
    # but often enough, especially in large datasets. It is currently under investigation.
    #
    # Complexity: O(log n)
    #
    #   map = Containers::TreeMap.new
    #   map.push("MA", "Massachusetts")
    #   map.push("GA", "Georgia")
    #   map.min_key #=> "GA"
    def delete(key)
      result = nil
      if @root
        @root, result = delete_recursive(@root, key)
        @root.color = :black if @root
      end
      result
    end

    # Returns true if the tree is empty, false otherwise
    def empty?
      @root.nil?
    end

    # Deletes the item with the smallest key and returns the item. Returns nil
    # if key is not present.
    #
    # Complexity: O(log n)
    #
    #   map = Containers::TreeMap.new
    #   map.push("MA", "Massachusetts")
    #   map.push("GA", "Georgia")
    #   map.delete_min #=> "Massachusetts"
    #   map.size #=> 1
    def delete_min
      result = nil
      if @root
        @root, result = delete_min_recursive(@root)
        @root.color = :black if @root
      end
      result
    end

    # Deletes the item with the largest key and returns the item. Returns nil
    # if key is not present.
    #
    # Complexity: O(log n)
    #
    #   map = Containers::TreeMap.new
    #   map.push("MA", "Massachusetts")
    #   map.push("GA", "Georgia")
    #   map.delete_max #=> "Georgia"
    #   map.size #=> 1
    def delete_max
      result = nil
      if @root
        @root, result = delete_max_recursive(@root)
        @root.color = :black if @root
      end
      result
    end

    # Iterates over the TreeMap from smallest to largest element. Iterative approach.
    def each
      return nil unless @root
      stack = Containers::Stack.new
      cursor = @root
      loop do
        if cursor
          stack.push(cursor)
          cursor = cursor.left
        elsif stack.empty?
          break
        else
          cursor = stack.pop
          yield(cursor.key, cursor.value)
          cursor = cursor.right
        end
      end
    end

    class Node # :nodoc: all
      attr_accessor :color, :key, :value, :left, :right, :size, :height
      def initialize(key, value)
        @key = key
        @value = value
        @color = :red
        @left = nil
        @right = nil
        @size = 1
        @height = 1
      end

      def red?
        @color == :red
      end

      def colorflip
        @color = @color == :red ? :black : :red
        @left.color = @left.color == :red ? :black : :red
        @right.color = @right.color == :red ? :black : :red
      end

      def update_size
        @size = (@left ? @left.size : 0) + (@right ? @right.size : 0) + 1
        left_height = (@left ? @left.height : 0)
        right_height = (@right ? @right.height : 0)
        @height = if left_height > right_height
          left_height + 1
        else
          right_height + 1
        end
        self
      end

      def rotate_left
        r = @right
        r_key, r_value, r_color = r.key, r.value, r.color
        b = r.left
        r.left = @left
        @left = r
        @right = r.right
        r.right = b
        r.color, r.key, r.value = :red, @key, @value
        @key, @value = r_key, r_value
        r.update_size
        update_size
      end

      def rotate_right
        l = @left
        l_key, l_value, l_color = l.key, l.value, l.color
        b = l.right
        l.right = @right
        @right = l
        @left = l.left
        l.left = b
        l.color, l.key, l.value = :red, @key, @value
        @key, @value = l_key, l_value
        l.update_size
        update_size
      end

      def move_red_left
        colorflip
        if @right.left && @right.left.red?
          @right.rotate_right
          rotate_left
          colorflip
        end
        self
      end

      def move_red_right
        colorflip
        if @left.left && @left.left.red?
          rotate_right
          colorflip
        end
        self
      end

      def fixup
        rotate_left if @right && @right.red?
        rotate_right if (@left && @left.red?) && (@left.left && @left.left.red?)
        colorflip if (@left && @left.red?) && (@right && @right.red?)

        update_size
      end
    end

    def delete_recursive(node, key)
      if (key <=> node.key) == -1
        node.move_red_left if !isred(node.left) && !isred(node.left.left)
        node.left, result = delete_recursive(node.left, key)
      else
        node.rotate_right if isred(node.left)
        if ((key <=> node.key) == 0) && node.right.nil?
          return nil, node.value
        end
        if !isred(node.right) && !isred(node.right.left)
          node.move_red_right
        end
        if (key <=> node.key) == 0
          result = node.value
          node.value = get_recursive(node.right, min_recursive(node.right))
          node.key = min_recursive(node.right)
          node.right = delete_min_recursive(node.right).first
        else
          node.right, result = delete_recursive(node.right, key)
        end
      end
      [node.fixup, result]
    end
    private :delete_recursive

    def delete_min_recursive(node)
      if node.left.nil?
        return nil, node.value
      end
      if !isred(node.left) && !isred(node.left.left)
        node.move_red_left
      end
      node.left, result = delete_min_recursive(node.left)

      [node.fixup, result]
    end
    private :delete_min_recursive

    def delete_max_recursive(node)
      if isred(node.left)
        node = node.rotate_right
      end
      return nil, node.value if node.right.nil?
      if !isred(node.right) && !isred(node.right.left)
        node.move_red_right
      end
      node.right, result = delete_max_recursive(node.right)

      [node.fixup, result]
    end
    private :delete_max_recursive

    private def get_recursive_node_for_key(node, key)
      return nil if node.nil?

      case key <=> node.key
      when 0 then node
      when -1 then get_recursive_node_for_key(node.left, key)
      when 1 then get_recursive_node_for_key(node.right, key)
      end
    end

    def get_recursive(node, key)
      return nil if node.nil?
      case key <=> node.key
      when 0 then node.value
      when -1 then get_recursive(node.left, key)
      when 1 then get_recursive(node.right, key)
      end
    end
    private :get_recursive

    def min_recursive(node)
      return node.key if node.left.nil?

      min_recursive(node.left)
    end
    private :min_recursive

    def max_recursive(node)
      return node.key if node.right.nil?

      max_recursive(node.right)
    end
    private :max_recursive

    def insert(node, key, value)
      return @node_klass.new(key, value) unless node

      case key <=> node.key
      when 0 then node.value = value
      when -1 then node.left = insert(node.left, key, value)
      when 1 then node.right = insert(node.right, key, value)
      end

      node.rotate_left if node.right && node.right.red?
      node.rotate_right if node.left && node.left.red? && node.left.left && node.left.left.red?
      node.colorflip if node.left && node.left.red? && node.right && node.right.red?
      node.update_size
    end
    private :insert

    def isred(node)
      return false if node.nil?

      node.color == :red
    end
    private :isred
  end


  class RangeCmp
    attr_reader :first, :last

    def initialize(range)
      @first = range.first
      @last = range.last
    end

    def annotate
      @last
    end

    def <=>(other)
      case @first <=> other.first
      when 1
        1
      when -1
        -1
      when 0
        @last <=> other.last
      end
    end

    def to_s
      "#{@first..last}"
    end

    def inspect
      "#{self.class} (#{self.object_id}): #{to_s}"
    end
  end

  # Compares end before beginning
  class RangeCmpRev < RangeCmp
    def annotate
      @first
    end

    def <=>(other)
      case @last <=> other.last
      when 1
        1
      when -1
        -1
      when 0
        @first <=> other.first
      end
    end
  end

  class AnnotateNode < Containers::RubyRBTreeMap::Node
    attr_accessor :annotate, :parent

    def initialize(key, value)
      super
      @annotate = key.annotate
      @parent = nil
    end

    def left=(node)
      @left = node
      node.parent = self if node
    end

    def right=(node)
      @right = node
      node.parent = self if node
    end
  end


  class BinaryIntervalTree < Containers::RubyRBTreeMap

    def initialize
      super(node_klass: AnnotateNode)
    end

    def search_contains_key(key)
      search_contains_rec(@root, key)
    end

    def search_contains_annotate_key(key)
      search_contains_rec_annotate(@root, key)
    end

    def insert(node, key, value)
      if node && (key.annotate <=> node.annotate) == 1 # greater than
        node.annotate = key.annotate
      end
      super
    end
    private :insert

    private def search_contains_rec_annotate(node, key, result = [])
      return result if node.nil?

      if node.key.last <= key.last
        if node.key.first >= key.first
          result << node
        end
        # go both if (node.key.first MAX) > key.first

        if node.annotate > key.first
          search_contains_rec_annotate(node.left, key, result)
          search_contains_rec_annotate(node.right, key, result)
        end
      else
        # go right if annotate (node.key.first MAX) > key.first
        if node.annotate > key.first
          search_contains_rec_annotate(node.right, key, result)
        end
      end

      result
    end

    private def search_contains_rec(node, key, result = [])
      return result if node.nil?

      if node.key.first >= key.first
        # Node may have overlap, and may be contained

        if node.key.last <= key.last
          # Node is contained, add it to the list and keep searching
          # It's children may also be contained too
          #
          # Nodes to the left will have smaller start && || end
          # Nodes to the right will have larger start && || end

          result << node
        else
          # End of node was too large to be contained
          # may still have an overlap
          #
          # Nodes to the left will have smaller start && || end
          # Nodes to the right will have larger start && || end
        end
        search_contains_rec(node.left, key, result)
        search_contains_rec(node.right, key, result)
      else
        # Node is outside of containment because it starts too soon,
        # Doesn't matter where it ends
        # look right
        search_contains_rec(node.right, key, result)
      end
      result
    end
  end

  class BinaryIntervalTree::Debug < BinaryIntervalTree
    attr_accessor :count

    def initialize
      super
      @count = 0
    end

    private def search_contains_rec_annotate(node, key, result = [])
      @count += 1
      super
    end

    private def search_contains_rec(node, key, result = [])
      @count += 1
      super
    end
  end
end
