# frozen_string_literal: true

module JsonMask
  # One entry of a {SelectionTree}: either a leaf, which selects a field's
  # whole value, or a nested selection into that value's members.
  #
  # Selections are immutable. Read them from a {SelectionTree}; the
  # constructors are internal to the parser.
  class Selection
    # @return [SelectionTree, nil] the nested selections, or nil for a leaf
    attr_reader :children

    # @api private
    def self.leaf
      @leaf ||= new
    end

    # @api private
    def initialize(children = nil)
      @children = children
      freeze
    end

    # @return [Boolean] true when the field's whole value is selected
    def leaf?
      children.nil?
    end

    # @api private
    def merge(other)
      return self.class.leaf if leaf? || other.leaf?

      self.class.new(children.merge(other.children))
    end
  end

  # One level of a compiled selector: the fields named explicitly plus an
  # optional wildcard. Repeated names are merged by union, and a leaf wins
  # over a nested selection of the same name.
  #
  # Trees are immutable. Read a selector's root tree from
  # {CompiledMask#selection_tree}; the constructors are internal to the parser.
  class SelectionTree
    # @return [Hash{String => Selection}] the explicitly named selections,
    #   keyed by unescaped field name
    attr_reader :named

    # @return [Selection, nil] the +*+ selection at this level, if any
    attr_reader :wildcard

    # @api private
    def self.empty
      @empty ||= new
    end

    # @api private
    def self.single(name:, wildcard:, children: nil)
      selection = children ? Selection.new(children) : Selection.leaf

      if wildcard
        new(wildcard: selection)
      else
        new(named: { name => selection })
      end
    end

    # @api private
    def initialize(named: {}, wildcard: nil)
      @named = named.freeze
      @wildcard = wildcard
      @effective_named = effective_named.freeze
      freeze
    end

    # @api private
    def merge(other)
      self.class.new(
        named: named.merge(other.named) { |_name, left, right| left.merge(right) },
        wildcard: merge_wildcards(other)
      )
    end

    # The selection the projector applies to a field: the named selection
    # merged with the wildcard's nested selections, or the wildcard alone for
    # a field that is not named.
    #
    # @param key [String, Symbol] a field name
    # @return [Selection, nil] nil when the field is not selected
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
