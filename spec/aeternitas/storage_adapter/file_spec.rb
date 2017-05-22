require 'spec_helper'
require 'shared/storage_adapter'

describe Aeternitas::StorageAdapter::File do
  it_behaves_like 'a storage adapter', Aeternitas::StorageAdapter::File.new(Aeternitas.config.storage_adapter_config)
end