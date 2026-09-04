# frozen_string_literal: true

module JsonMask
  module Projector
    MISSING = Object.new.freeze

    module_function

    def call(value, selection_tree)
      projected = project(value, selection_tree)
      projected.equal?(MISSING) ? nil : projected
    end

    def project(value, selection_tree)
      case value
      when Hash
        project_hash(value, selection_tree)
      when Array
        project_array(value, selection_tree)
      when nil
        # Keep nulls, as the reference implementation does, so a nullable
        # field stays distinguishable from an unselected one.
        nil
      else
        MISSING
      end
    end

    def project_hash(value, selection_tree)
      value.each_with_object({}) do |(key, field_value), result|
        selection = selection_tree.selection_for(key)
        next unless selection

        projected = selection.leaf? ? field_value : project(field_value, selection.children)
        result[key] = projected unless projected.equal?(MISSING)
      end
    end

    def project_array(value, selection_tree)
      value.each_with_object([]) do |item, result|
        projected = project(item, selection_tree)
        result << projected unless projected.equal?(MISSING)
      end
    end
  end
end
