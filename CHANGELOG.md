# Changelog

## 0.2.0 - Unreleased

- Expose compiled selectors for inspection. `CompiledMask#selection_tree` returns the root
  `JsonMask::SelectionTree`; its `named`, `wildcard`, and `selection_for` readers and
  `JsonMask::Selection`'s `leaf?` and `children` are public API. Applications that have a
  response schema can use the tree to reject selectors that name undeclared fields.

## 0.1.0 - 2026-08-04

- Implement Google partial-response and JSON Mask field selectors.
- Support comma-separated fields, slash paths, sub-selections, wildcards, and escaping.
- Add reusable compiled masks and parser resource limits.
- Add a `json-mask` entry file so Bundler's default require works without a `require:` option.
- Preserve `nil` values under nested selections, matching the reference implementation.
