# frozen_string_literal: true

require_relative '../data/repositories/google_translation_repository'
require_relative '../data/repositories/mock_translation_repository'
require_relative '../data/repositories/file_system_repository'
require_relative '../data/repositories/sqlite_cost_repository'
require_relative '../data/repositories/sqlite_memory_repository'
require_relative '../domain/services/translator_service'
require_relative '../domain/services/bleu_scorer'
require_relative '../use_cases/translate_text_use_case'
require_relative '../use_cases/process_file_use_case'
require_relative '../features/cost_tracker'
require_relative '../features/batch_processor'
require_relative '../features/export_manager'
require_relative '../infrastructure/secure_storage'

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
                  :export_manager, :cost_tracker, :secure_storage

      private

      def setup_repositories
        if ENV['TF_USE_MOCK'] == '1'
          @translation_repository = Data::Repositories::MockTranslationRepository.new
        else
          @translation_repository = Data::Repositories::GoogleTranslationRepository.new(:unofficial)
        end
        @file_repository = Data::Repositories::FileSystemRepository.new
        @cost_repository = Data::Repositories::SqliteCostRepository.new
        @memory_repository = Data::Repositories::SqliteMemoryRepository.new
      end

      def setup_services
        @cost_tracker = ENV['TF_COST_TRACKING_ENABLED'] == '1' ? Features::CostTracker.new(@cost_repository) : nil
        @translator_service = Domain::Services::TranslatorService.new(
          @translation_repository,
          @memory_repository,
          @cost_tracker
        )
        @bleu_scorer = Domain::Services::BleuScorer.new
      end

      def setup_use_cases
        @translate_use_case = UseCases::TranslateTextUseCase.new(@translator_service, @bleu_scorer)
        @process_file_use_case = UseCases::ProcessFileUseCase.new(@file_repository, @translate_use_case)
      end

      def setup_features
        @batch_processor = Features::BatchProcessor.new(@process_file_use_case, @file_repository)
        @export_manager = Features::ExportManager.new(@bleu_scorer)
        @secure_storage = Infrastructure::SecureStorage.new
      end
    end
  end
end
