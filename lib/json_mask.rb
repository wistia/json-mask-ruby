# frozen_string_literal: true

require_relative 'json_mask/version'
require_relative 'json_mask/error'
require_relative 'json_mask/selection_tree'
require_relative 'json_mask/parser'
require_relative 'json_mask/projector'
require_relative 'json_mask/compiled_mask'

# Filters JSON-compatible Ruby values using Google partial-response selectors.
module JsonMask
  class << self
    # Filters a JSON-compatible value with a field selector. Blank selectors
    # return the value unchanged.
    def call(value, fields, **options)
      compile(fields, **options).call(value)
    end

    alias mask call

    # Compiles a selector for reuse across multiple values. Raises ParseError
    # for a malformed selector and LimitError when it exceeds a limit.
    def compile(
      fields,
      max_length: Parser::DEFAULT_MAX_LENGTH,
      max_depth: Parser::DEFAULT_MAX_DEPTH,
      max_selectors: Parser::DEFAULT_MAX_SELECTORS
    )
      selection_tree = Parser.new(
        fields,
        max_length:,
        max_depth:,
        max_selectors:
      ).parse

      CompiledMask.new(fields, selection_tree)
    end
  end

  private_constant :Parser, :Projector
end
