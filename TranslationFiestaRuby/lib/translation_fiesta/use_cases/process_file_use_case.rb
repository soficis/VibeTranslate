# frozen_string_literal: true

require_relative '../domain/entities/file_item'

module TranslationFiesta
  module UseCases
    class ProcessFileUseCase
      def initialize(file_repository, translate_use_case)
        @file_repository = file_repository
        @translate_use_case = translate_use_case
      end

      def execute(file_path, api_type = :unofficial)
        file_item = Domain::Entities::FileItem.new(file_path)
        
        raise ArgumentError, "File not supported: #{file_item.type}" unless file_item.supported?
        raise ArgumentError, "File not readable: #{file_path}" unless file_item.readable?

        content = file_repository.read_text_file(file_path)
        raise ArgumentError, 'File is empty or contains no readable text' if content.strip.empty?

        result = translate_use_case.execute(content, api_type)
        
        {
          file_item: file_item,
          translation_result: result
        }
      end

      private

      attr_reader :file_repository, :translate_use_case
    end
  end
end