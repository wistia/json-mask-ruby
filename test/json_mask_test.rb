# frozen_string_literal: true

require_relative 'test_helper'

class JsonMaskTest < Minitest::Test
  def test_selects_multiple_fields
    input = { 'id' => 1, 'name' => 'Demo', 'duration' => 30 }

    assert_equal({ 'id' => 1, 'name' => 'Demo' }, JsonMask.call(input, 'id,name'))
  end

  def test_selects_nested_fields_with_slashes
    input = {
      'name' => 'Demo',
      'capabilities' => { 'canDownload' => true, 'canEdit' => false }
    }

    expected = { 'capabilities' => { 'canDownload' => true } }

    assert_equal expected, JsonMask.call(input, 'capabilities/canDownload')
  end

  def test_slash_paths_traverse_arrays
    input = {
      'permissions' => [
        { 'id' => 'one', 'role' => 'owner' },
        { 'id' => 'two', 'role' => 'viewer' }
      ]
    }

    expected = { 'permissions' => [{ 'role' => 'owner' }, { 'role' => 'viewer' }] }

    assert_equal expected, JsonMask.call(input, 'permissions/role')
  end

  def test_parenthesized_subselections_traverse_objects_and_arrays
    input = {
      'files' => [
        {
          'id' => 'one',
          'name' => 'First',
          'permissions' => [{ 'role' => 'owner', 'email' => 'owner@example.com' }]
        },
        { 'id' => 'two', 'name' => 'Second', 'permissions' => [] }
      ],
      'nextPageToken' => 'next',
      'kind' => 'drive#fileList'
    }

    expected = {
      'files' => [
        { 'id' => 'one', 'permissions' => [{ 'role' => 'owner' }] },
        { 'id' => 'two', 'permissions' => [] }
      ],
      'nextPageToken' => 'next'
    }

    fields = 'files(id,permissions(role)),nextPageToken'
    assert_equal expected, JsonMask.call(input, fields)
  end

  def test_wildcard_selects_every_field
    input = { 'id' => 1, 'metadata' => { 'a' => 2, 'b' => 3 } }

    assert_equal input, JsonMask.call(input, '*')
    refute_same input, JsonMask.call(input, '*')
  end

  def test_wildcards_can_have_nested_selections
    input = {
      'first' => { 'id' => 1, 'name' => 'First' },
      'second' => { 'id' => 2, 'name' => 'Second' }
    }

    expected = { 'first' => { 'id' => 1 }, 'second' => { 'id' => 2 } }

    assert_equal expected, JsonMask.call(input, '*(id)')
  end

  def test_explicit_fields_are_unioned_with_a_nested_wildcard
    input = {
      'first' => { 'id' => 1, 'name' => 'First' },
      'featured' => { 'id' => 2, 'name' => 'Featured' }
    }

    expected = {
      'first' => { 'id' => 1 },
      'featured' => { 'id' => 2, 'name' => 'Featured' }
    }

    assert_equal expected, JsonMask.call(input, '*(id),featured')
  end

  def test_repeated_fields_are_unioned_and_a_leaf_selection_wins
    input = { 'item' => { 'id' => 1, 'name' => 'Demo', 'extra' => true } }

    assert_equal(
      { 'item' => { 'id' => 1, 'name' => 'Demo' } },
      JsonMask.call(input, 'item/id,item/name')
    )
    assert_equal input, JsonMask.call(input, 'item/id,item')
  end

  def test_escapes_structural_characters
    input = {
      'a/b' => 1,
      'a,b' => 2,
      'a(b)' => 3,
      '*' => 4,
      '\\' => 5,
      'other' => 6
    }
    fields = 'a\/b,a\,b,a\(b\),\*,\\'

    expected = input.except('other')

    assert_equal expected, JsonMask.call(input, fields)
  end

  def test_an_asterisk_inside_a_name_is_not_a_wildcard
    input = { 'a*' => 1, '*a' => 2, 'a' => 3 }

    assert_equal({ 'a*' => 1, '*a' => 2 }, JsonMask.call(input, 'a*,*a'))
  end

  def test_whitespace_around_syntax_is_ignored_and_internal_whitespace_is_preserved
    input = { 'first' => 1, 'last' => 2, 'display name' => 3, 'ignored' => 4 }

    fields = ' first , last , display name '

    assert_equal input.except('ignored'), JsonMask.call(input, fields)
  end

  def test_string_and_symbol_keys_are_preserved
    input = { id: 1, 'name' => 'Demo', ignored: true }

    assert_equal({ id: 1, 'name' => 'Demo' }, JsonMask.call(input, 'id,name'))
  end

  def test_the_input_is_not_mutated
    input = { 'items' => [{ 'id' => 1, 'name' => 'First' }] }
    original = Marshal.load(Marshal.dump(input))

    JsonMask.call(input, 'items/id')

    assert_equal original, input
  end

  def test_missing_fields_and_shape_mismatches_are_omitted
    input = {
      'missingChild' => 'scalar',
      'items' => [{ 'other' => 1 }, { 'id' => 2 }],
      'untouched' => true
    }

    expected = { 'items' => [{}, { 'id' => 2 }] }

    assert_equal expected, JsonMask.call(input, 'absent,missingChild/id,items/id')
  end

  def test_null_values_pass_through_nested_selections
    input = { 'id' => 1, 'folder' => nil }

    assert_equal input, JsonMask.call(input, 'id,folder(name)')
    assert_equal({ 'folder' => nil }, JsonMask.call(input, 'folder/name'))
  end

  def test_null_array_items_are_preserved_under_nested_selections
    input = { 'items' => [{ 'id' => 1, 'extra' => 2 }, nil] }

    assert_equal({ 'items' => [{ 'id' => 1 }, nil] }, JsonMask.call(input, 'items(id)'))
  end

  def test_a_nil_root_returns_nil
    assert_nil JsonMask.call(nil, 'id')
  end

  def test_the_gem_loads_by_its_dashed_name
    lib = File.expand_path('../lib', __dir__)
    program = 'require "json-mask"; print JsonMask::VERSION'
    output, status = Open3.capture2(RbConfig.ruby, '-I', lib, '-e', program)

    assert_predicate status, :success?
    assert_equal JsonMask::VERSION, output
  end

  def test_root_arrays_are_supported
    input = [{ 'id' => 1, 'name' => 'One' }, { 'id' => 2, 'name' => 'Two' }]

    assert_equal [{ 'id' => 1 }, { 'id' => 2 }], JsonMask.call(input, 'id')
  end

  def test_a_non_container_root_returns_nil
    assert_nil JsonMask.call('scalar', 'id')
  end

  def test_nil_and_blank_fields_return_the_original_value
    input = { 'id' => 1 }

    assert_same input, JsonMask.call(input, nil)
    assert_same input, JsonMask.call(input, '')
    assert_same input, JsonMask.call(input, " \n\t")
  end

  def test_compiled_masks_can_be_reused
    mask = JsonMask.compile('id,nested/value')

    assert_predicate mask, :frozen?
    assert_equal 'id,nested/value', mask.fields
    assert_equal({ 'id' => 1 }, mask.call({ 'id' => 1, 'other' => 2 }))
    assert_equal({ 'nested' => { 'value' => 3 } },
                 mask.filter({ 'nested' => { 'value' => 3, 'x' => 4 } }))
  end

  def test_mask_is_an_alias_for_call
    input = { 'id' => 1, 'name' => 'Demo' }

    assert_equal({ 'id' => 1 }, JsonMask.mask(input, 'id'))
  end

  def test_invalid_field_types_are_rejected
    error = assert_raises(TypeError) { JsonMask.compile(['id']) }

    assert_equal 'fields must be a String or nil', error.message
  end

  def test_malformed_selectors_include_the_offset
    cases = {
      'id,' => 3,
      'id,,name' => 3,
      'files(id' => 8,
      'files()' => 6,
      'files//id' => 6,
      'files(id))' => 9
    }

    cases.each do |fields, offset|
      error = assert_raises(JsonMask::ParseError) { JsonMask.compile(fields) }

      assert_equal fields, error.expression
      assert_equal offset, error.offset
      assert_match(/at offset #{offset}\z/, error.message)
    end
  end

  def test_length_limit
    error = assert_raises(JsonMask::LimitError) do
      JsonMask.compile('abcdef', max_length: 5)
    end

    assert_match(/longer than 5 bytes/, error.message)
  end

  def test_length_limit_applies_to_blank_selectors
    error = assert_raises(JsonMask::LimitError) do
      JsonMask.compile('      ', max_length: 5)
    end

    assert_match(/longer than 5 bytes/, error.message)
  end

  def test_depth_limit
    JsonMask.compile('a/b', max_depth: 2)

    error = assert_raises(JsonMask::LimitError) do
      JsonMask.compile('a/b/c', max_depth: 2)
    end

    assert_match(/deeper than 2/, error.message)
  end

  def test_selector_count_limit
    error = assert_raises(JsonMask::LimitError) do
      JsonMask.compile('a,b,c', max_selectors: 2)
    end

    assert_match(/more than 2 fields/, error.message)
  end

  def test_limits_must_be_positive_integers
    error = assert_raises(ArgumentError) { JsonMask.compile('id', max_depth: 0) }

    assert_equal 'max_depth must be a positive Integer', error.message
  end

  def test_compiled_masks_expose_their_selection_tree
    tree = JsonMask.compile('id,permissions(role),items/*/id').selection_tree

    assert_kind_of JsonMask::SelectionTree, tree
    assert_equal %w[id permissions items], tree.named.keys
    assert_nil tree.wildcard
    assert_predicate tree.named['id'], :leaf?
    assert_nil tree.named['id'].children
  end

  def test_selection_trees_nest_parenthesized_selections
    permissions = JsonMask.compile('permissions(role)').selection_tree.named['permissions']

    refute_predicate permissions, :leaf?
    assert_equal ['role'], permissions.children.named.keys
    assert_predicate permissions.children.named['role'], :leaf?
  end

  def test_selection_trees_nest_wildcard_paths
    items = JsonMask.compile('items/*/id').selection_tree.named['items'].children

    assert_empty items.named
    assert_equal ['id'], items.wildcard.children.named.keys
  end

  def test_blank_selectors_compile_without_a_selection_tree
    assert_nil JsonMask.compile(nil).selection_tree
    assert_nil JsonMask.compile('').selection_tree
    assert_nil JsonMask.compile(" \n\t").selection_tree
  end

  def test_selection_trees_are_frozen
    tree = JsonMask.compile('id,nested/value').selection_tree

    assert_predicate tree, :frozen?
    assert_predicate tree.named, :frozen?
    assert_predicate tree.named['nested'], :frozen?
    assert_raises(FrozenError) { tree.named['other'] = tree.named['id'] }
  end

  def test_selection_trees_keep_wildcards_separate_from_named_selections
    tree = JsonMask.compile('*(id),featured,detailed(name)').selection_tree

    assert_equal %w[featured detailed], tree.named.keys
    assert_equal ['id'], tree.wildcard.children.named.keys
  end

  def test_selection_for_merges_the_wildcard_into_named_selections
    tree = JsonMask.compile('*(id),featured,detailed(name)').selection_tree

    assert_predicate tree.selection_for('featured'), :leaf?
    assert_equal %w[name id], tree.selection_for('detailed').children.named.keys
    assert_same tree.wildcard, tree.selection_for('other')
  end

  def test_selection_for_accepts_string_and_symbol_keys_and_is_nil_for_unselected_fields
    tree = JsonMask.compile('id').selection_tree

    assert_same tree.named['id'], tree.selection_for('id')
    assert_same tree.named['id'], tree.selection_for(:id)
    assert_nil tree.selection_for('other')
  end

  def test_repeated_selections_are_merged_in_the_tree
    tree = JsonMask.compile('item/id,item/name').selection_tree

    assert_equal %w[id name], tree.named['item'].children.named.keys

    tree = JsonMask.compile('item/id,item').selection_tree

    assert_predicate tree.named['item'], :leaf?
  end

  def test_selection_tree_names_are_unescaped
    tree = JsonMask.compile('a\/b,\*,a\(b\)').selection_tree

    assert_equal ['a/b', '*', 'a(b)'], tree.named.keys
    assert_nil tree.wildcard
  end

  def test_selection_trees_support_schema_aware_validation
    schema = {
      'type' => 'object',
      'properties' => {
        'id' => { 'type' => 'string' },
        'permissions' => {
          'type' => 'array',
          'items' => { 'type' => 'object', 'properties' => { 'role' => { 'type' => 'string' } } }
        }
      }
    }
    tree = JsonMask.compile('id,permissions(role,email),owner/name').selection_tree

    assert_equal ['permissions/email', 'owner'], undeclared_paths(tree, schema)
  end

  private

  def undeclared_paths(tree, schema, path = [])
    schema = schema['items'] if schema['type'] == 'array'
    properties = schema.fetch('properties', {})

    tree.named.flat_map do |name, selection|
      property = properties[name]
      next [(path + [name]).join('/')] unless property
      next [] if selection.leaf?

      undeclared_paths(selection.children, property, path + [name])
    end
  end
end
