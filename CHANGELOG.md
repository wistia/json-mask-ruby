# Changelog

## 0.1.0 - Unreleased

- Implement Google partial-response and JSON Mask field selectors.
- Support comma-separated fields, slash paths, sub-selections, wildcards, and escaping.
- Add reusable compiled masks and parser resource limits.
- Add a `json-mask` entry file so Bundler's default require works without a `require:` option.
- Preserve `nil` values under nested selections, matching the reference implementation.
