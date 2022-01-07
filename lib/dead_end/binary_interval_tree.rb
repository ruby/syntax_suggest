# frozen_string_literal: true

module DeadEnd


  # AVL tree
  class BinaryTree
    class RangeCmp
      attr_reader :first, :last

      def initialize(range)
        @first = range.first
        @last = range.last
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
        (@first..last).to_s
      end

      def inspect
        (@first..last).inspect
      end
    end

    class RangeNode
      attr_accessor :key, :data, :height, :left, :right, :deleted

      attr_reader :first, :last

      def initialize key, data
        self.key = RangeCmp.new(key)
        self.data = data
        self.height = 1
      end

      def <=>(other)
        @key <=> other.key
      end
    end

    # Represents an entry into the avl tree.
    class GeneralNode
      attr_accessor :key, :data, :height, :left, :right, :deleted

      def initialize key, data
        self.key = key
        self.data = data
        self.height = 1
      end

      def <=>(other)
        @key <=> other.key
      end
    end

    attr_reader :klass

    def initialize(klass: GeneralNode)
      @klass = klass
      @root = nil
    end

    # Adds a new node to the the tree.
    def insert key, data = nil
      node = klass.new(key,data)
      @root = insert_and_balance(@root, node)
      node
    end

    def remove_node(node)
      node&.deleted = true
    end

    # Removes a node from the tree.
    def remove key
      # This method finds the node to be removed and marks it as deleted.
      # This is a nice way to handle deletions because since the structure
      # doesn't change we don't have to balance the tree after removals.
      delete_node(search(key))
    end

    def search_node(node)
      node = search_node_rec(@root, node)
      return node unless node&.deleted
    end

    private def search_node_rec(node, looking_for)
      return nil unless node

      cmp = looking_for <=> node
      return search_node_rec(node.left, looking_for) if cmp == -1
      return search_node_rec(node.right, looking_for) if cmp == 1
      node
    end

    # Searches for a key in the current tree.
    def search_key(key)
      node = search_key_rec @root, key
      return node unless node&.deleted
    end

    # Prints the contents of a tree.
    def print
      print_rec @root, 0
    end

    # Inserts a new node and balances the tree (if needed).
    private def insert_and_balance(node, new_node = nil)
      return new_node unless node

      cmp = new_node <=> node
      if cmp == -1
        node.left = insert_and_balance(node.left, new_node)
      elsif cmp == 1
        node.right = insert_and_balance(node.right, new_node)
      else
        node.data = data
        node.deleted = false
      end

      balance(node)
    end

    # Prints the subtree that starts at the provided node.
    private def print_rec(node = @root, indent = 0)
      unless node
        puts "x".rjust(indent * 2, " ")
        return
      end

      puts_key node, indent
      print_rec node.left, indent + 1
      print_rec node.right, indent + 1
    end

    # Returns the heigh of the provided node.
    private def height node
      node&.height || 0
    end

    # Calculates and sets the height for the specified node.
    private def set_height node
      lh = height node&.left
      rh = height node&.right
      max = lh > rh ? lh : rh

      node.height = 1 + max
    end

    # Performs a right rotation.
    private def rotate_right p
      q = p.left
      p.left = q.right
      q.right = p

      set_height p
      set_height q

      q
    end

    # Performs a left rotation.
    private def rotate_left p
      q = p.right
      p.right = q.left
      q.left = p

      set_height p
      set_height q

      q
    end

    # Performs a LR rotation.
    private def rotate_left_right node
      node.left = rotate_left(node.left)
      rotate_right(node)
    end

    # Performs a RL rotation.
    private def rotate_right_left node
      node.right = rotate_right(node.right)
      rotate_left(node)
    end

    # Balances the subtree rooted at the specify node if that tree needs
    # to be balanced.
    private def balance node
      set_height node

      if height(node.left) - height(node.right) == 2
        if height(node.left.right) > height(node.left.left)
          # LR rotation.
          return rotate_left_right(node.left)
        end
        ## RR rotation (or just right rotation).
        return rotate_right(node)
      elsif height(node.right) - height(node.left) == 2
        if height(node.right.left) > height(node.right.right)
          # RL rotation.
          return rotate_right_left(node.right)
        end
        # LL rotation (or just left rotation).
        return rotate_left(node)
      end
      node
    end

    # Searches for a key in the subtree that starts at the provided node.
    private def search_key_rec node, key
      return nil unless node
      return search_key_rec(node.left, key) if key < node.key
      return search_key_rec(node.right, key) if key > node.key
      node
    end

    # Print the contents of a key.
    private def puts_key(node, indent)
      txt = node.key.to_s
      if node.deleted
        txt += " (D)"
        puts txt.rjust(indent * 8, " ")
      else
        puts txt.rjust(indent * 4, " ")
      end
    end
  end

  class BinaryIntervalTree < BinaryTree

    def initialize
      super(klass: RangeNode)
    end

    def search_contains_key(key)
      search_contains_rec(@root, key)
    end

    private def search_contains_rec(node, key, result = [])
      return result if node.nil? || node.deleted

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
end
