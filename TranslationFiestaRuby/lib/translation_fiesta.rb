# frozen_string_literal: true

require_relative 'translation_fiesta/version'
require_relative 'translation_fiesta/application'
require_relative 'translation_fiesta/cli'

# Load domain modules for proper namespace resolution
require_relative 'translation_fiesta/domain/entities/translation_result'
require_relative 'translation_fiesta/domain/entities/file_item'
require_relative 'translation_fiesta/domain/repositories/translation_repository'
require_relative 'translation_fiesta/domain/repositories/file_repository'
require_relative 'translation_fiesta/domain/repositories/memory_repository'
require_relative 'translation_fiesta/domain/services/translator_service'
require_relative 'translation_fiesta/domain/services/bleu_scorer'
require_relative 'translation_fiesta/use_cases/translate_text_use_case'
require_relative 'translation_fiesta/use_cases/process_file_use_case'

module TranslationFiesta
  class Error < StandardError; end
  class TranslationError < Error; end
  class FileProcessingError < Error; end
  class APIError < Error; end
end
