# frozen_string_literal: true

module JsonMask
  # An immutable, reusable field selector.
  class CompiledMask
    attr_reader :fields

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
