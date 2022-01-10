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
      when 0
        node.value = value
      when -1
        node.left = insert(node.left, key, value)
      when 1
        node.right = insert(node.right, key, value)
      end

      node.rotate_left if node.right && node.right.red?
      node.rotate_right if node.left && node.left.red? && node.left.left && node.left.left.red?
      node.colorflip if node.left && node.left.red? && node.right && node.right.red?
      node.update_size

      node
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
    alias :high :last
    alias :low :first

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

    def rotate_left
      r = @right
      r_key, r_value, r_color, r_annotate = r.key, r.value, r.color, r.annotate
      b = r.left
      r.left = @left
      @left = r
      @right = r.right
      r.right = b
      r.color, r.key, r.value, r.annotate = :red, @key, @value, @annotate
      @key, @value, @annotate = r_key, r_value, r_annotate
      r.update_size
      update_size
    end

    def rotate_right
      l = @left
      l_key, l_value, l_color, l_annotate = l.key, l.value, l.color, l.annotate
      b = l.right
      l.right = @right
      @right = l
      @left = l.left
      l.left = b
      l.color, l.key, l.value, l.annotate = :red, @key, @value, @annotate
      @key, @value, @annotate = l_key, l_value, @annotate
      l.update_size
      update_size
    end
  end

  class BinaryIntervalTree < Containers::RubyRBTreeMap
    def initialize
      super(node_klass: AnnotateNode)
    end

    def delete_engulf(search)
      found = []
      deleted = []
      while n = search_overlap(@root, search)
        if search.low <= n.key.low && n.key.high <= search.high
          deleted << n.value
        else
          found << [n.key, n.value]
        end

        delete(n.key)
      end

      found.each do |(k, v)|
        # puts "Fixing #{k}"
        push(k, v)
      end

      deleted
    end

    private def search_overlap(node, search)
      return if node.nil?

      # i1.low <= i2.high && i2.low <= i1.high

      if node.key.low <= search.high && search.low <= node.key.high
        return node
      end

      if node.left && node.left.annotate > search.low
        search_overlap(node.left, search)
      else
        search_overlap(node.right, search)
      end
    end

    private def search_engulf_rec(node, search)
      return if node.nil?

      if search.low > node.annotate
        return nil
      end

      if search.low <= node.key.low
        # Maybe left, maybe right, maybe match
        if search.high >= node.key.high
          return node
        else

          # At this point low will only increase, if it is higher than
          # the search.high, it cannot exist to the right
          # TODO

          out = search_engulf_rec(node.right, search)

          out ||= search_engulf_rec(node.left, search)
          return out
        end
      else
        # Current low range value is the biggest possible on the left
        # if we are not >= it, we will never find a match, go right
        return search_engulf_rec(node.right, search)
      end
    end

    # No elimination logic, checks all nodes
    def search_contains_key(key)
      search_contains_rec(@root, key)
    end

    def force_annotate_check(node = @root)
      return true if node.nil?

      if node.left
        if node.left.key.annotate > node.annotate
          print_tree
          raise "expected #{node.key}: #{node.right.key.annotate} never to be larger than #{node.annotate} but it was"
        end
      end

      if node.right
        if node.right.key.annotate > node.annotate
          print_tree
          raise "expected #{node.key}: #{node.right.key.annotate} never to be larger than #{node.annotate} but it was"
        end
      end

      force_annotate_check(node.left)
      force_annotate_check(node.right)
    end


    # No elimination logic, checks all nodes
    private def search_contains_rec(node, key, result = [])
      return result if node.nil?

      if node.key.first >= key.first

        if node.key.last <= key.last
          result << node
        end
      end

      search_contains_rec(node.left, key, result)
      search_contains_rec(node.right, key, result)

      result
    end

    def insert(node, key, value)
      out = super

      annotate_from_kids(out)

      out
    end

    def force_reannotate(node = @root)
      return if node.nil?

      force_reannotate(node.left)
      force_reannotate(node.right)
      annotate_from_kids(node)
    end

    def annotate_from_kids(node)
      return if node.nil?

      node.annotate = node.key.annotate

      if node.left && node.left.annotate > node.annotate
        node.annotate = node.left.annotate
      end

      if node.right && node.right.annotate > node.annotate
        node.annotate = node.right.annotate
      end
      node
    end

    private :insert

    def print_tree
      print_rec(@root)
      puts
    end

    private def print_rec(node, indent: 2, name: "")
      if node.nil?
        puts " " * indent + "#{name} ∅️"
      else
        puts " " * indent + "#{name} #{node.key} annotate: #{node.annotate}".strip
        print_rec(node.right, indent: indent + 2, name: "R:")
        print_rec(node.left, indent: indent + 2, name: "L:")
      end
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
