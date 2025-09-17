# frozen_string_literal: true

module TranslationFiesta
  module Domain
    module Repositories
      class MemoryRepository
        def get_translation(source_text, from_lang, to_lang)
          raise NotImplementedError, 'Subclasses must implement get_translation'
        end

        def save_translation(source_text, from_lang, to_lang, translated_text)
          raise NotImplementedError, 'Subclasses must implement save_translation'
        end

        def clear_cache
          raise NotImplementedError, 'Subclasses must implement clear_cache'
        end

        def cache_size
          raise NotImplementedError, 'Subclasses must implement cache_size'
        end
      end
    end
  end
end