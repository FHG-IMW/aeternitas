module Aeternitas
  module Errors
    class Ignored < StandardError
      attr_reader :original_error

      def initialize(original_error)
        @original_error = original_error
        super("#{original_error.class} - #{original_error.message}")
      end

    end
  end
end