module Aeternitas
  module Errors
    # Wrapper for ignored errors.
    # This can be used to conveniently exclude certain errors from e.g. error trackers
    # @!attribute [r] original error
    #   the wrapped error
    class Ignored < StandardError
      attr_reader :original_error

      # Create a new Instance.
      #
      # @param [StandardError] original_error the wrapped error
      def initialize(original_error)
        @original_error = original_error
        super("#{original_error.class} - #{original_error.message}")
      end

    end

    class SourceEntryExists < StandardError
      attr_reader :fingerprint
      def initialize(fingerprint)
        @fingerprint = fingerprint
        super("The source entry with fingerprint '#{fingerprint}' already exists!")
      end
    end

    class SourceEntryDoesNotExist < StandardError
      attr_reader :fingerprint
      def initialize(fingerprint)
        @fingerprint = fingerprint
        super("The source entry with fingerprint '#{fingerprint}' does not exist!")
      end
    end
  end
end