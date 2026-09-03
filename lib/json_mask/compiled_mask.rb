# frozen_string_literal: true

module JsonMask
  # An immutable, reusable field selector.
  class CompiledMask
    # @return [String, nil] the selector expression as given
    attr_reader :fields

    # The compiled selections, for callers that inspect a selector rather than
    # apply it, such as checking field names against a response schema.
    #
    # @return [SelectionTree, nil] the root tree, or nil when the selector was
    #   blank and values pass through unchanged
    attr_reader :selection_tree

    def initialize(fields, selection_tree)
      @fields = fields&.dup&.freeze
      @selection_tree = selection_tree
      freeze
    end

    # Filters a JSON-compatible value using this selector.
    #
    # @param value [Hash, Array] response data to filter
    # @return [Hash, Array, nil] a structural subset of value
    def call(value)
      return value unless @selection_tree

      Projector.call(value, @selection_tree)
    end

    alias filter call
  end
end
