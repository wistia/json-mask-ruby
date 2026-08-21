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

  def test_except_removes_top_level_fields
    input = { 'id' => 1, 'name' => 'Demo', 'email' => 'owner@example.com' }

    assert_equal({ 'id' => 1, 'name' => 'Demo' }, JsonMask.except(input, 'email'))
  end

  def test_except_removes_nested_fields_with_slashes
    input = {
      'name' => 'Demo',
      'capabilities' => { 'canDownload' => true, 'canEdit' => false }
    }

    expected = { 'name' => 'Demo', 'capabilities' => { 'canDownload' => true } }

    assert_equal expected, JsonMask.except(input, 'capabilities/canEdit')
  end

  def test_except_subselections_traverse_objects_and_arrays
    input = {
      'files' => [
        {
          'id' => 'one',
          'permissions' => [{ 'role' => 'owner', 'email' => 'owner@example.com' }]
        },
        { 'id' => 'two', 'permissions' => [] }
      ],
      'nextPageToken' => 'next'
    }

    expected = {
      'files' => [
        { 'id' => 'one', 'permissions' => [{ 'role' => 'owner' }] },
        { 'id' => 'two', 'permissions' => [] }
      ],
      'nextPageToken' => 'next'
    }

    assert_equal expected, JsonMask.except(input, 'files(permissions(email))')
  end

  def test_except_removes_whole_subtrees
    input = { 'id' => 1, 'permissions' => [{ 'role' => 'owner' }] }

    assert_equal({ 'id' => 1 }, JsonMask.except(input, 'permissions'))
  end

  def test_except_applies_to_each_item_of_a_top_level_array
    input = [
      { 'id' => 1, 'email' => 'a@example.com' },
      { 'id' => 2, 'email' => 'b@example.com' }
    ]

    assert_equal [{ 'id' => 1 }, { 'id' => 2 }], JsonMask.except(input, 'email')
  end

  def test_except_keeps_scalars_and_nils_under_nested_exclusions
    input = { 'a' => 1, 'b' => nil, 'c' => { 'x' => 1, 'y' => 2 } }

    expected = { 'a' => 1, 'b' => nil, 'c' => { 'x' => 1 } }

    assert_equal expected, JsonMask.except(input, 'a/x,b/x,c/y')
  end

  def test_except_missing_fields_are_a_noop
    input = { 'id' => 1 }

    assert_equal({ 'id' => 1 }, JsonMask.except(input, 'email,contact/email'))
  end

  def test_except_wildcard_removes_every_field
    input = { 'id' => 1, 'nested' => { 'x' => 1 } }

    assert_empty JsonMask.except(input, '*')
  end

  def test_except_nested_wildcard_empties_the_field
    input = { 'id' => 1, 'nested' => { 'x' => 1, 'y' => 2 } }

    assert_equal({ 'id' => 1, 'nested' => {} }, JsonMask.except(input, 'nested/*'))
  end

  def test_except_with_blank_selectors_returns_the_value_unchanged
    input = { 'id' => 1 }

    assert_same input, JsonMask.except(input, nil)
    assert_same input, JsonMask.except(input, '')
    assert_same input, JsonMask.except(input, " \n\t")
  end

  def test_except_preserves_symbol_keys_and_does_not_mutate_the_input
    input = { id: 1, email: 'owner@example.com' }

    assert_equal({ id: 1 }, JsonMask.except(input, 'email'))
    assert_equal({ id: 1, email: 'owner@example.com' }, input)
  end

  def test_compiled_exclusion_masks_can_be_reused
    mask = JsonMask.compile_except('email')

    assert_predicate mask, :frozen?
    assert_equal 'email', mask.fields
    assert_equal({ 'id' => 1 }, mask.call({ 'id' => 1, 'email' => 'a@example.com' }))
    assert_equal({ 'id' => 2 }, mask.filter({ 'id' => 2, 'email' => 'b@example.com' }))
  end

  def test_compile_except_enforces_limits
    assert_raises(JsonMask::LimitError) { JsonMask.compile_except('abcdef', max_length: 5) }
    assert_raises(JsonMask::LimitError) { JsonMask.compile_except('a/b/c', max_depth: 2) }
    assert_raises(JsonMask::LimitError) { JsonMask.compile_except('a,b,c', max_selectors: 2) }
  end

  def test_compile_except_rejects_malformed_selectors
    error = assert_raises(JsonMask::ParseError) { JsonMask.compile_except('files(id') }

    assert_equal 'files(id', error.expression
  end
end
