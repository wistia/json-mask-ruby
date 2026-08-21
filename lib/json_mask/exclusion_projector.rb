# frozen_string_literal: true

module JsonMask
  # Applies a compiled selection tree as an exclusion: matched fields are
  # removed and every other field passes through unchanged.
  module ExclusionProjector
    module_function

    def call(value, selection_tree)
      exclude(value, selection_tree)
    end

    def exclude(value, selection_tree)
      case value
      when Hash
        exclude_hash(value, selection_tree)
      when Array
        exclude_array(value, selection_tree)
      else
        value
      end
    end

    def exclude_hash(value, selection_tree)
      value.each_with_object({}) do |(key, field_value), result|
        selection = selection_tree.selection_for(key)

        if selection.nil?
          result[key] = field_value
        elsif !selection.leaf?
          result[key] = exclude(field_value, selection.children)
        end
      end
    end

    def exclude_array(value, selection_tree)
      value.map { |item| exclude(item, selection_tree) }
    end
  end
end
