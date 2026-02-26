# frozen_string_literal: true

require_relative '../data/repositories/google_translation_repository'
require_relative '../data/repositories/mock_translation_repository'
require_relative '../data/repositories/file_system_repository'
require_relative '../data/repositories/sqlite_memory_repository'
require_relative '../domain/services/translator_service'
require_relative '../use_cases/translate_text_use_case'
require_relative '../use_cases/process_file_use_case'
require_relative '../features/batch_processor'
require_relative '../features/export_manager'
require_relative 'app_paths'

module TranslationFiesta
  module Infrastructure
    class DependencyContainer
      def initialize
        setup_repositories
        setup_services
        setup_use_cases
        setup_features
      end

      attr_reader :translate_use_case, :process_file_use_case, :batch_processor,
                  :export_manager, :file_repository

      private

      def setup_repositories
        if ENV['TF_USE_MOCK'] == '1'
          @translation_repository = Data::Repositories::MockTranslationRepository.new
        else
          @translation_repository = Data::Repositories::GoogleTranslationRepository.new(:unofficial)
        end
        @file_repository = Data::Repositories::FileSystemRepository.new
        @memory_repository = Data::Repositories::SqliteMemoryRepository.new(AppPaths.memory_db_path)
      end

      def setup_services
        @translator_service = Domain::Services::TranslatorService.new(
          @translation_repository,
          @memory_repository
        )
      end

      def setup_use_cases
        @translate_use_case = UseCases::TranslateTextUseCase.new(@translator_service)
        @process_file_use_case = UseCases::ProcessFileUseCase.new(@file_repository, @translate_use_case)
      end

      def setup_features
        @batch_processor = Features::BatchProcessor.new(@process_file_use_case, @file_repository)
        @export_manager = Features::ExportManager.new
      end
    end
  end
end
