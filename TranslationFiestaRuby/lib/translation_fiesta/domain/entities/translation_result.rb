# frozen_string_literal: true

module TranslationFiesta
  module Domain
    module Entities
      class TranslationResult
        attr_reader :original_text, :first_translation, :back_translation,
                    :api_type, :timestamp

        def initialize(original_text:, first_translation:, back_translation:,
                      api_type:, timestamp: Time.now)
          @original_text = original_text
          @first_translation = first_translation
          @back_translation = back_translation
          @api_type = api_type
          @timestamp = timestamp
        end

        def to_hash
          {
            original_text: original_text,
            first_translation: first_translation,
            back_translation: back_translation,
            api_type: api_type,
            timestamp: timestamp
          }
        end
      end
    end
  end
end
