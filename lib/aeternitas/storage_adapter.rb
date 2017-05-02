require "aeternitas/storage_adapter/file"
module Aeternitas
  # Storage Adapters take care of handling source files.
  # @abstract Create a subclass and override {#store}, #{retrieve} and #{#delete} to create a new storage adapter
  class StorageAdapter

    # Create a new storage adapter
    # @param [Hash] config the adapters configuration
    def initialize(config)
      @config = config
    end

    # Store a new entry with the given id and raw content
    # @abstract
    # @param [String] id the entries fingerprint
    # @param [Object] raw_content the raw content object
    def store(id, raw_content)
      raise NotImplementedError, "#{self.class.name} does not implement #store, required by Aeternitas::StorageAdapter"
    end

    # Retrieves the content of the entry with the given fingerprint
    # @abstract
    # @param [String] id the entries fingerprint
    # @return [String] the entries content
    def retrieve(id)
      raise NotImplementedError, "#{self.class.name} does not implement #retrive, required by Aeternitas::StorageAdapter"
    end

    # Delete the entry with the given fingerprint
    # @abstract
    # @param [String] id the entries fingerprint
    # @return [Boolean] Operation state
    def delete(id)
      raise NotImplementedError, "#{self.class.name} does not implement #delete, required by Aeternitas::StorageAdapter"
    end

    # Checks whether the entry with the given fingerprint exists.
    # @param [String] id the entries id
    # @return [Boolean] if the entry exists
    def exist?(id)
      raise NotImplementedError, "#{self.class.name} does not implement #exist?, required by Aeternitas::StorageAdapter"
    end

  end
end