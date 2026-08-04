# frozen_string_literal: true

module JsonMask
  # Compiles a field selector string into an immutable selection tree.
  class Parser
    DEFAULT_MAX_LENGTH = 16_384
    DEFAULT_MAX_DEPTH = 64
    DEFAULT_MAX_SELECTORS = 1_000

    TERMINALS = [',', '/', '(', ')'].freeze
    WHITESPACE = [' ', "\t", "\n", "\r"].freeze

    def initialize(expression, max_length:, max_depth:, max_selectors:)
      validate_expression!(expression)
      validate_limit!(:max_length, max_length)
      validate_limit!(:max_depth, max_depth)
      validate_limit!(:max_selectors, max_selectors)

      @expression = expression
      @max_length = max_length
      @max_depth = max_depth
      @max_selectors = max_selectors
    end

    def parse
      return if @expression.nil?

      enforce_length!
      return if @expression.strip.empty?

      @characters = @expression.each_char.to_a
      @index = 0
      @selector_count = 0
      parse_list(depth: 1)
    end

    private

    def parse_list(depth:, terminator: nil)
      tree = SelectionTree.empty
      expect_selection!(terminator)

      loop do
        tree = tree.merge(parse_selection(depth))
        skip_whitespace

        break if finish_list?(terminator)

        expect_character!(',')
        advance
        expect_selection!(terminator)
      end

      tree
    end

    def parse_selection(depth)
      enforce_depth!(depth)
      name, wildcard = parse_name
      count_selector!
      skip_whitespace

      children = case current_character
                 when '/'
                   advance
                   parse_selection(depth + 1)
                 when '('
                   advance
                   parse_list(depth: depth + 1, terminator: ')')
                 end

      SelectionTree.single(name:, wildcard:, children:)
    end

    def parse_name
      skip_whitespace
      entries = []

      while current_character && !TERMINALS.include?(current_character)
        entries << next_name_character
      end

      entries.pop while trailing_whitespace?(entries.last)
      parse_error!('expected a field name') if entries.empty?

      name = entries.map(&:first).join
      wildcard = entries == [['*', false]]
      [name, wildcard]
    end

    def next_name_character
      character = current_character
      unless character == '\\'
        advance
        return [character, false]
      end

      advance
      return ['\\', false] unless current_character

      character = current_character
      advance
      [character, true]
    end

    def finish_list?(terminator)
      if terminator && current_character == terminator
        advance
        return true
      end

      return true if current_character.nil? && terminator.nil?

      parse_error!("expected #{terminator.inspect}") if current_character.nil?
      false
    end

    def expect_selection!(terminator)
      skip_whitespace
      unless current_character.nil? || current_character == ',' || current_character == terminator
        return
      end

      parse_error!('expected a field name')
    end

    def expect_character!(expected)
      return if current_character == expected

      parse_error!("expected #{expected.inspect}")
    end

    def skip_whitespace
      advance while WHITESPACE.include?(current_character)
    end

    def trailing_whitespace?(entry)
      entry && !entry.last && WHITESPACE.include?(entry.first)
    end

    def current_character
      @characters[@index]
    end

    def advance
      @index += 1
    end

    def count_selector!
      @selector_count += 1
      return if @selector_count <= @max_selectors

      limit_error!("selector contains more than #{@max_selectors} fields")
    end

    def enforce_length!
      return if @expression.bytesize <= @max_length

      limit_error!("selector is longer than #{@max_length} bytes", offset: 0)
    end

    def enforce_depth!(depth)
      return if depth <= @max_depth

      limit_error!("selector nesting is deeper than #{@max_depth}")
    end

    def validate_expression!(expression)
      return if expression.nil?

      raise TypeError, 'fields must be a String or nil' unless expression.is_a?(String)
      raise ArgumentError, 'fields must use valid UTF-8' unless expression.valid_encoding?
    end

    def validate_limit!(name, value)
      return if value.is_a?(Integer) && value.positive?

      raise ArgumentError, "#{name} must be a positive Integer"
    end

    def parse_error!(reason, offset: @index)
      raise ParseError.new(reason, expression: @expression, offset:)
    end

    def limit_error!(reason, offset: @index || 0)
      raise LimitError.new(reason, expression: @expression, offset:)
    end
  end
end
