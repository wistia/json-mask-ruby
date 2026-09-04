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
  end
end
