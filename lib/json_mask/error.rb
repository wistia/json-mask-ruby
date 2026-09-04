# frozen_string_literal: true

module JsonMask
  class ParseError < ArgumentError
    attr_reader :expression, :offset, :reason

    def initialize(reason, expression:, offset:)
      @reason = reason
      @expression = expression
      @offset = offset

      super("#{reason} at offset #{offset}")
    end
  end

  # A ParseError subclass so one rescue covers malformed and oversized selectors.
  class LimitError < ParseError
  end
end
