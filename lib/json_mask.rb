# frozen_string_literal: true

require_relative 'json_mask/version'
require_relative 'json_mask/error'
require_relative 'json_mask/selection_tree'
require_relative 'json_mask/parser'
require_relative 'json_mask/projector'
require_relative 'json_mask/compiled_mask'

module JsonMask
  WILDCARD = :*

  class << self
    def call(value, fields, **options)
      compile(fields, **options).call(value)
    end

    alias mask call

    # Formats a path from CompiledMask#each_path, or a prefix of one, as a selector.
    #
    # @param path [Array<String, Symbol>] unescaped field names and WILDCARD segments
    # @return [String] a slash-separated selector with literal names escaped
    def format_path(path)
      path.map do |name|
        name == WILDCARD ? '*' : name.gsub(%r{[\\,/()*\s\x00]}) { |character| "\\#{character}" }
      end.join('/')
    end

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
