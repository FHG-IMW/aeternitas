RSpec.shared_examples 'a storage adapter' do |adapter|
  let(:raw_content) {'Lorem ipsum dolor sit amet, consectetur adipiscing elit.'}
  let(:fingerprint) { Digest::MD5.hexdigest(raw_content) }

  describe '#store' do
    it 'stores the content', tmpFiles: true do
      adapter.store(fingerprint, raw_content)
      expect(adapter.exist?(fingerprint)).to be(true)
    end

    it 'raises an error when the entry already exists', tmpFiles: true do
      adapter.store(fingerprint, raw_content)
      expect { adapter.store(fingerprint, raw_content) }.to(
        raise_error(Aeternitas::Errors::SourceDataExists) { |e| expect(e.fingerprint).to be(fingerprint) }
      )
    end
  end

  describe '#retrieve' do
    it 'retrieves the content', tmpFiles: true do
      adapter.store(fingerprint, raw_content)
      expect(adapter.retrieve(fingerprint)).to eq(raw_content)
    end

    it 'raises an error when the entry does not exists', tmpFiles: true do
      expect { adapter.retrieve(fingerprint) }.to(
        raise_error(Aeternitas::Errors::SourceDataNotFound) { |e| expect(e.fingerprint).to be(fingerprint) }
      )
    end
  end

  describe '#delete', tmpFiles: true do
    it 'deletes an existing entry' do
      adapter.store(fingerprint, raw_content)
      expect(adapter.delete(fingerprint)).to be(true)
      expect(adapter.exist?(fingerprint)).to be(false)
    end

    it 'returns false if the entry does not exist', tmpFiles: true do
      expect(adapter.delete(fingerprint)).to be(false)
    end
  end

  describe '#exist?', tmpFiles: true do
    it 'returns true if the entry exists' do
      adapter.store(fingerprint, raw_content)
      expect(adapter.exist?(fingerprint)).to be(true)
    end

    it 'returns false if the entry does not exist', tmpFiles: true do
      expect(adapter.exist?(fingerprint)).to be(false)
    end
  end

end