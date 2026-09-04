# frozen_string_literal: true

require_relative 'json_mask/version'
require_relative 'json_mask/error'
require_relative 'json_mask/selection_tree'
require_relative 'json_mask/parser'
require_relative 'json_mask/projector'
require_relative 'json_mask/compiled_mask'

module JsonMask
  class << self
    def call(value, fields, **options)
      compile(fields, **options).call(value)
    end

    alias mask call

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
