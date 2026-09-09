# Changelog

## 0.3.0 - 2026-09-09

- Add `CompiledMask#each_path` to enumerate selected paths with decoded field names and a distinct
  `JsonMask::WILDCARD` token. Whole-field selections absorb descendants, and terminal wildcards
  absorb sibling selections.
- Add `JsonMask.format_path` to turn a path or prefix into an escaped slash-separated selector.

## 0.2.0 - 2026-09-04

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
