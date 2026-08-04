# frozen_string_literal: true

module JsonMask
  # Represents either a complete field or a field with nested selections.
  class Selection
    attr_reader :children

    def self.leaf
      @leaf ||= new
    end

    def initialize(children = nil)
      @children = children
      freeze
    end

    def leaf?
      children.nil?
    end

    def merge(other)
      return self.class.leaf if leaf? || other.leaf?

      self.class.new(children.merge(other.children))
    end
  end

  # Stores named and wildcard selections, merging repeated selections by union.
  class SelectionTree
    attr_reader :named, :wildcard

    def self.empty
      @empty ||= new
    end

    def self.single(name:, wildcard:, children: nil)
      selection = children ? Selection.new(children) : Selection.leaf

      if wildcard
        new(wildcard: selection)
      else
        new(named: { name => selection })
      end
    end

    def initialize(named: {}, wildcard: nil)
      @named = named.freeze
      @wildcard = wildcard
      @effective_named = effective_named.freeze
      freeze
    end

    def merge(other)
      self.class.new(
        named: named.merge(other.named) { |_name, left, right| left.merge(right) },
        wildcard: merge_wildcards(other)
      )
    end

    def selection_for(key)
      @effective_named.fetch(key.to_s, wildcard)
    end

    private

    def effective_named
      return named unless wildcard

      named.transform_values { |selection| selection.merge(wildcard) }
    end

    def merge_wildcards(other)
      return other.wildcard unless wildcard
      return wildcard unless other.wildcard

      wildcard.merge(other.wildcard)
    end
  end
end
