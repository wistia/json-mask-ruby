# frozen_string_literal: true

module JsonMask
  # Raised when a field selector does not conform to the supported grammar.
  class ParseError < ArgumentError
    attr_reader :expression, :offset, :reason

    def initialize(reason, expression:, offset:)
      @reason = reason
      @expression = expression
      @offset = offset

      super("#{reason} at offset #{offset}")
    end
  end

  # Raised when a field selector exceeds a configured parser limit.
  class LimitError < ParseError
  end
end
