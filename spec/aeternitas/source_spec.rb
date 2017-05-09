require 'spec_helper'

describe Aeternitas::Source do
  let(:raw_content) {'Lorem ipsum dolor sit amet, consectetur adipiscing elit.'}
  let(:source) {Aeternitas::Source.new(raw_content: raw_content, pollable: SimplePollable.new)}
  let(:storage_adapter) {Aeternitas.config.get_storage_adapter}

  around(:each) do |example|
    MemFs.activate { example.run }
  end

  describe 'generating a new source' do
    it 'generates a fingerprint for every instance' do
      expect(source.fingerprint).not_to be_nil
    end

    it 'save the raw_content on creation' do
      source.save!
      expect(storage_adapter.exist?(source.fingerprint)).to be(true)
      expect(storage_adapter.retrieve(source.fingerprint)).to eq(raw_content)
    end

    it 'does not save the file if the creation transaction is canceled' do
      ActiveRecord::Base.transaction do
        source.save!
        raise ActiveRecord::Rollback
      end
      expect(storage_adapter.exist?(source.fingerprint)).to be(false)
    end
  end

  describe 'destroying the source' do
    before(:each) {source.save!}
    it 'deletes the raw content' do
      source.destroy!
      expect(storage_adapter.exist?(source.fingerprint)).to be(false)
    end

    it 'does not delete the raw content if the deletion transaction is canceled' do
      ActiveRecord::Base.transaction do
        source.destroy!
        raise ActiveRecord::Rollback
      end
      expect(storage_adapter.exist?(source.fingerprint)).to be(true)
    end
  end

  describe '#generate_fingerprint' do
    it 'hashes the raw_content' do
      expect(source.generate_fingerprint).to eq(Digest::MD5.hexdigest(raw_content))
    end
  end

  describe '#raw_content' do
    it 'retieves the source content' do
      source.save!
      expect(Aeternitas::Source.first.raw_content).to eq(raw_content)
    end
  end
end