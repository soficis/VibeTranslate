# frozen_string_literal: true

require 'keyring'

module TranslationFiesta
  module Infrastructure
    class SecureStorage
      SERVICE_NAME = 'TranslationFiestaRuby'

      def store_api_key(key_name, api_key)
        if keyring_available?
          Keyring.set_password(SERVICE_NAME, key_name, api_key)
        else
          store_in_file(key_name, api_key)
        end
      end

      def retrieve_api_key(key_name)
        if keyring_available?
          Keyring.get_password(SERVICE_NAME, key_name)
        else
          retrieve_from_file(key_name)
        end
      rescue StandardError
        nil
      end

      def delete_api_key(key_name)
        if keyring_available?
          Keyring.delete_password(SERVICE_NAME, key_name)
        else
          delete_from_file(key_name)
        end
      end

      def list_stored_keys
        if keyring_available?
          # Keyring doesn't support listing, so we maintain our own list
          stored_keys = retrieve_api_key('_stored_keys') || ''
          stored_keys.split(',').reject(&:empty?)
        else
          list_from_files
        end
      end

      private

      def keyring_available?
        @keyring_available ||= begin
          Keyring.get_password('test', 'test')
          true
        rescue StandardError
          false
        end
      end

      def store_in_file(key_name, api_key)
        ensure_config_directory
        file_path = config_file_path(key_name)
        
        # Simple encryption using Base64 (not secure, but better than plain text)
        encoded_key = [api_key].pack('m0')
        File.write(file_path, encoded_key, mode: 'wb')
        File.chmod(0600, file_path) # Restrict file permissions
      end

      def retrieve_from_file(key_name)
        file_path = config_file_path(key_name)
        return nil unless File.exist?(file_path)

        encoded_key = File.read(file_path, mode: 'rb')
        encoded_key.unpack1('m0')
      end

      def delete_from_file(key_name)
        file_path = config_file_path(key_name)
        File.delete(file_path) if File.exist?(file_path)
      end

      def list_from_files
        return [] unless Dir.exist?(config_directory)

        Dir.glob(File.join(config_directory, '*.key')).map do |file_path|
          File.basename(file_path, '.key')
        end
      end

      def config_directory
        File.join(Dir.home, '.translation_fiesta')
      end

      def ensure_config_directory
        Dir.mkdir(config_directory, 0700) unless Dir.exist?(config_directory)
      end

      def config_file_path(key_name)
        File.join(config_directory, "#{key_name}.key")
      end
    end
  end
end