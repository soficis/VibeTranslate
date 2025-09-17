# frozen_string_literal: true

require_relative '../entities/translation_result'

module TranslationFiesta
  module Domain
    module Services
      class TranslatorService
        def initialize(translation_repo, memory_repo = nil, cost_tracker = nil)
          @translation_repo = translation_repo
          @memory_repo = memory_repo
          @cost_tracker = cost_tracker
        end

        def perform_back_translation(text, api_type = :unofficial)
          validate_input(text)
          
          # Check translation memory first
          cached_result = check_translation_memory(text, api_type)
          return cached_result if cached_result

          # Perform actual translation
          first_translation = translate_with_memory(text, 'en', 'ja', api_type)
          back_translation = translate_with_memory(first_translation, 'ja', 'en', api_type)

          cost = calculate_cost(text, first_translation, api_type)
          track_cost(cost, text.length, api_type) if @cost_tracker

          result = Entities::TranslationResult.new(
            original_text: text,
            first_translation: first_translation,
            back_translation: back_translation,
            api_type: api_type,
            cost: cost
          )

          # Cache the complete result
          cache_translation_result(result) if @memory_repo

          result
        end

        def detect_language(text)
          @translation_repo.detect_language(text)
        end

        private

        attr_reader :translation_repo, :memory_repo, :cost_tracker

        def validate_input(text)
          raise ArgumentError, 'Text cannot be nil or empty' if text.nil? || text.strip.empty?
          raise ArgumentError, 'Text is too long (max 5000 characters)' if text.length > 5000
        end

        def check_translation_memory(text, api_type)
          return nil unless memory_repo

          cached_first = memory_repo.get_translation(text, 'en', 'ja')
          return nil unless cached_first

          cached_back = memory_repo.get_translation(cached_first, 'ja', 'en')
          return nil unless cached_back

          Entities::TranslationResult.new(
            original_text: text,
            first_translation: cached_first,
            back_translation: cached_back,
            api_type: api_type,
            cost: 0.0
          )
        end

        def translate_with_memory(text, from_lang, to_lang, api_type)
          # Check memory first
          if memory_repo
            cached = memory_repo.get_translation(text, from_lang, to_lang)
            return cached if cached
          end

          # Perform actual translation
          result = translation_repo.translate_text(text, from_lang, to_lang, api_type)

          # Cache the result
          memory_repo&.save_translation(text, from_lang, to_lang, result)

          result
        end

        def calculate_cost(original_text, first_translation, api_type)
          return 0.0 if api_type == :unofficial

          character_count = original_text.length + first_translation.length
          character_count * 0.00002 # Google Translate pricing: $20 per 1M characters
        end

        def track_cost(cost, character_count, api_type)
          cost_tracker.track_translation_cost(
            cost: cost,
            character_count: character_count,
            api_type: api_type
          )
        end

        def cache_translation_result(result)
          memory_repo.save_translation(
            result.original_text, 'en', 'ja', result.first_translation
          )
          memory_repo.save_translation(
            result.first_translation, 'ja', 'en', result.back_translation
          )
        end
      end
    end
  end
end