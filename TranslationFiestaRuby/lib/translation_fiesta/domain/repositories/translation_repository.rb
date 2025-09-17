# frozen_string_literal: true

module TranslationFiesta
  module Domain
    module Repositories
      class TranslationRepository
        def translate_text(text, from_language, to_language, api_type)
          raise NotImplementedError, 'Subclasses must implement translate_text'
        end

        def detect_language(text)
          raise NotImplementedError, 'Subclasses must implement detect_language'
        end

        def available?
          raise NotImplementedError, 'Subclasses must implement available?'
        end
      end
    end
  end
end