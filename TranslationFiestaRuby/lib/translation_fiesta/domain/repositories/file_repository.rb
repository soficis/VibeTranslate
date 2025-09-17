# frozen_string_literal: true

module TranslationFiesta
  module Domain
    module Repositories
      class FileRepository
        def read_text_file(file_path)
          raise NotImplementedError, 'Subclasses must implement read_text_file'
        end

        def write_text_file(file_path, content)
          raise NotImplementedError, 'Subclasses must implement write_text_file'
        end

        def list_files_in_directory(directory_path, extensions = nil)
          raise NotImplementedError, 'Subclasses must implement list_files_in_directory'
        end

        def file_exists?(file_path)
          raise NotImplementedError, 'Subclasses must implement file_exists?'
        end
      end
    end
  end
end