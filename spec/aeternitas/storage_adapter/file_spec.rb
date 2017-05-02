require 'spec_helper'
require 'shared/storage_adapter'

describe Aeternitas::StorageAdapter::File do
  it_behaves_like 'a storage adapter', Aeternitas::StorageAdapter::File.new(directory: "/tmp")
end