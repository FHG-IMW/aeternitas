module Aeternitas
  class StorageAdapter
    # A storage adapter that stores the entries on disk.
    class File < Aeternitas::StorageAdapter

      # Create a new File storage adapter.
      # @param [Hash] config the adapters config
      # @option config [String] :directory specifies where the entries are stored
      def initialize(config)
        super
      end

      def store(id, raw_content)
        path = file_path(id)
        ensure_folders_exist(path)
        raise(Aeternitas::Errors::SourceEntryExists, id) if ::File.exist?(path)
        ::File.open(path, 'w+', encoding: 'ascii-8bit') do |f|
          f.write(Zlib.deflate(raw_content, Zlib::BEST_COMPRESSION))
        end
      end

      def retrieve(id)
        raise(Aeternitas::Errors::SourceEntryDoesNotExist, id) unless exist?(id)
        Zlib.inflate(::File.read(file_path(id), encoding: 'ascii-8bit'))
      end

      def delete(id)
        begin
          !!::File.delete(file_path(id))
        rescue Errno::ENOENT => e
          return false
        end
      end

      def exist?(id)
        ::File.exist?(file_path(id))
      end

      # Returns the byte size of the entry.
      # @param [String] id the entries fingerprint
      # @return [Integer] the entries size in byte
      def content_size(id)
        retrieve(id).bytesize
      end

      # Returns the compressed size of the entry.
      # @param [String] id the entries fingerprint
      # @return [Integer] the entries size on disk in byte
      def file_size_disk(id)
        ::File.size(file_path(id))
      end

      private

      # Calculates the location of the entry given it's fingerprint.
      # @param [String] id the entries fingerprint
      # @return [String] the entries location
      def file_path(id)
        ::File.join(
            @config[:directory],
            id[0..1], id[2..3], id[4..5],
            id[6..-1]
        )
      end

      # Makes sure that the storage location exists.
      def ensure_folders_exist(path)
        folders = ::File.dirname(path)
        FileUtils.mkdir_p(folders) unless Dir.exist?(folders)
      end
    end
  end
end