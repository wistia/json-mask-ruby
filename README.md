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

## Exclusion masks

`JsonMask.except` applies a selector as an exclusion: matched fields are removed and every other
field passes through unchanged.

```ruby
JsonMask.except(response, "permissions/email")
# => {
#      "id" => "abc123",
#      "name" => "Product demo",
#      "permissions" => [{"id" => "owner", "role" => "owner"}]
#    }
```

`JsonMask.compile_except` compiles a reusable exclusion mask, mirroring `JsonMask.compile`:

```ruby
mask = JsonMask.compile_except("email,phone_number")

mask.call(first_response)
mask.call(second_response)
```

Exclusion masks use the same selector grammar, parser limits, and traversal rules as selection.
Sub-selections and slash paths remove nested fields while keeping their parents
(`permissions(email)` keeps `permissions` but removes each entry's `email`), arrays are traversed
transparently, and a wildcard removes every field at its level. Selectors naming missing fields
are a no-op, scalars under a nested exclusion are kept as-is, and a `nil` or blank selector
removes nothing.

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
schema-aware "Invalid field selection" error on its own.

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
