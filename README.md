# JSON Mask for Ruby

[![CI](https://github.com/wistia/json-mask-ruby/actions/workflows/ci.yml/badge.svg)](https://github.com/wistia/json-mask-ruby/actions/workflows/ci.yml)

`json-mask` selects fields from JSON-compatible Ruby objects while preserving the shape of the
response. It implements the field selector language used by Google's partial responses and the
[JSON Mask](https://github.com/nemtsov/json-mask) project.

The library has no runtime dependencies.

## Installation

Add the gem to your `Gemfile`:

```ruby
gem "json-mask"
```

Then run `bundle install`.

## Usage

```ruby
require "json_mask"

response = {
  "id" => "abc123",
  "name" => "Product demo",
  "permissions" => [
    {"id" => "owner", "role" => "owner", "email" => "owner@example.com"}
  ]
}

JsonMask.call(response, "id,permissions(id,role)")
# => {
#      "id" => "abc123",
#      "permissions" => [{"id" => "owner", "role" => "owner"}]
#    }
```

`JsonMask.mask` is an alias for `JsonMask.call`.

Compile selectors that will be reused:

```ruby
mask = JsonMask.compile("id,name,permissions(role)")

mask.call(first_response)
mask.call(second_response)
```

Compiled masks are immutable and safe to share between threads.

Passing `nil`, an empty string, or a whitespace-only string returns the original value unchanged.
This makes an optional HTTP `fields` parameter straightforward:

```ruby
render json: JsonMask.call(payload, params[:fields])
```

## Selector syntax

The syntax is loosely based on XPath:

| Selector | Meaning |
| --- | --- |
| `id,name` | Select multiple fields |
| `permissions/role` | Select a nested field |
| `permissions(id,role)` | Select multiple fields from an object or each object in an array |
| `permissions/*` | Select every field below `permissions` |
| `items/*/id` | Select `id` from every value below `items` |

Slash paths and parenthesized sub-selections traverse arrays transparently. Empty hashes remain in
arrays, preserving their positions. Missing fields are omitted.

Backslash escapes structural characters in field names:

```ruby
JsonMask.call({"a/b" => 1, "other" => 2}, 'a\/b')
# => {"a/b" => 1}

JsonMask.call({"*" => 1, "other" => 2}, '\\*')
# => {"*" => 1}
```

The structural characters are `,`, `/`, `(`, `)`, `*`, and `\\`. An asterisk is a wildcard only
when it is the entire, unescaped field name. Unescaped whitespace around field names and operators
is ignored; whitespace inside a field name is preserved.

String and symbol hash keys are supported, and the result preserves the key objects from the input.
The input is never mutated.

## Invalid selectors and limits

Malformed selectors raise `JsonMask::ParseError`, which includes the original expression and the
zero-based character offset:

```ruby
JsonMask.compile("files(id,,name)")
# raises JsonMask::ParseError: expected a field name at offset 9
```

The parser applies conservative defaults suitable for accepting selectors from HTTP or MCP clients:

- Maximum selector length: 16,384 bytes
- Maximum nesting depth: 64
- Maximum field selectors: 1,000

The limits can be tightened for a specific boundary:

```ruby
JsonMask.compile(fields, max_length: 1_024, max_depth: 16, max_selectors: 100)
```

Exceeding a limit raises `JsonMask::LimitError`, a subclass of `JsonMask::ParseError`.

Validation is syntactic. Because the library has no response schema, a well-formed selector that
names a field absent from the input simply omits that field; it cannot produce Google's
schema-aware "Invalid field selection" error on its own. An application that has a schema can
produce one by inspecting the compiled selector.

## Inspecting a compiled selector

`JsonMask::CompiledMask#selection_tree` exposes the parsed selector as an immutable tree, for
callers that need to examine a selector rather than apply it:

```ruby
tree = JsonMask.compile("id,permissions(role),*/kind").selection_tree

tree.named.keys                                        # => ["id", "permissions"]
tree.named["id"].leaf?                                 # => true
tree.named["permissions"].children.named.keys          # => ["role"]
tree.wildcard.children.named.keys                      # => ["kind"]
tree.selection_for("permissions").children.named.keys  # => ["role", "kind"]
tree.selection_for("other").children.named.keys        # => ["kind"]
```

- A `JsonMask::SelectionTree` holds `named`, a frozen `Hash` from each explicitly written field
  name (unescaped) to a `JsonMask::Selection`, and `wildcard`, the `*` selection at that level or
  `nil`.
- A `JsonMask::Selection` is either a leaf (`leaf?` is true and the whole value is selected) or
  has `children`, a nested `JsonMask::SelectionTree`.
- `selection_for(key)` returns what the projector applies to a key (`String` or `Symbol`): the
  named selection merged with the wildcard, the wildcard alone for a key that is not named, or
  `nil` when the key is not selected.

Blank selectors compile to a mask that passes values through, and its `selection_tree` is `nil`.

This is enough to add schema-aware validation. For example, to list the selected paths that a
JSON-Schema-style hash does not declare:

```ruby
def undeclared_paths(tree, schema, path = [])
  schema = schema["items"] if schema["type"] == "array"
  properties = schema.fetch("properties", {})

  tree.named.flat_map do |name, selection|
    property = properties[name]
    next [(path + [name]).join("/")] unless property
    next [] if selection.leaf?

    undeclared_paths(selection.children, property, path + [name])
  end
end

schema = {
  "type" => "object",
  "properties" => {
    "id" => {"type" => "string"},
    "permissions" => {
      "type" => "array",
      "items" => {"type" => "object", "properties" => {"role" => {"type" => "string"}}}
    }
  }
}

tree = JsonMask.compile("id,permissions(role,email),owner/name").selection_tree
undeclared_paths(tree, schema)
# => ["permissions/email", "owner"]
```

## Compatibility

The supported grammar follows the [Google Drive `fields` parameter rules](https://developers.google.com/workspace/drive/api/guides/fields-parameter)
and JSON Mask's documented grammar. This library intentionally validates malformed expressions
instead of attempting to recover from them.

The projector accepts JSON-compatible `Hash` and `Array` values. If a selected field contains a
scalar where the selector asks for nested fields, that field is omitted — except `nil`, which
passes through unchanged (matching the reference implementation), so a nullable field stays
distinguishable from an unselected one. A non-container root value with a non-empty selector
produces `nil`.

## Development

```sh
bundle install
bundle exec rake
bundle exec rake build
```

The default Rake task runs the full test suite and RuboCop.

## License

MIT. See [LICENSE.txt](LICENSE.txt).
