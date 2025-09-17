# frozen_string_literal: true

require_relative '../../domain/repositories/translation_repository'

module TranslationFiesta
  module Data
    module Repositories
      # A tiny mock translation repository for offline testing and CI.
      # It performs deterministic, trivial "translations" so the app can be
      # exercised without network access or API keys.
      class MockTranslationRepository < TranslationFiesta::Domain::Repositories::TranslationRepository
        def initialize
          # no-op
        end

        def translate_text(text, from_language, to_language, api_type)
          # Simple deterministic mock: return the original text tagged with language codes
          translated = "[#{to_language}] #{text}"
          translated
        end

        def detect_language(text)
          'en'
        end
      end
    end
  end
end
