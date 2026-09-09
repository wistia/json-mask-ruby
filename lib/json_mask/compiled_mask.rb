# frozen_string_literal: true

module JsonMask
  class CompiledMask
    attr_reader :fields

    # nil for a blank selector, which passes values through unchanged.
    attr_reader :selection_tree

    def initialize(fields, selection_tree)
      @fields = fields&.dup&.freeze
      @selection_tree = selection_tree
      freeze
    end

    def call(value)
      return value unless @selection_tree

      Projector.call(value, @selection_tree)
    end

    alias filter call

    # Yields selected paths with unescaped names and JsonMask::WILDCARD segments.
    # Whole-field selections absorb descendants; a terminal wildcard absorbs siblings.
    #
    # @yieldparam path [Array<String, Symbol>] a fresh array for each selected path
    # @return [Enumerator, CompiledMask] an enumerator without a block; self with a block
    def each_path(&block)
      return enum_for(__method__) unless block

      walk_paths(selection_tree, [], &block) if selection_tree
      self
    end

    private

    def walk_paths(tree, prefix, &block)
      return yield(prefix + [WILDCARD]) if tree.wildcard&.leaf?

      selections = tree.named.to_a
      selections << [WILDCARD, tree.wildcard] if tree.wildcard
      selections.each do |name, selection|
        path = prefix + [name]
        if selection.leaf?
          yield path
        else
          walk_paths(selection.children, path, &block)
        end
      end
    end
  end
end
