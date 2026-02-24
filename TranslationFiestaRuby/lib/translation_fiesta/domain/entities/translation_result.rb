# frozen_string_literal: true

module TranslationFiesta
  module Domain
    module Entities
      class TranslationResult
        attr_reader :original_text, :first_translation, :back_translation,
                    :api_type, :bleu_score, :timestamp

        def initialize(original_text:, first_translation:, back_translation:,
                      api_type:, bleu_score: nil, timestamp: Time.now)
          @original_text = original_text
          @first_translation = first_translation
          @back_translation = back_translation
          @api_type = api_type
          @bleu_score = bleu_score
          @timestamp = timestamp
        end

        def quality_rating
          return 'Unknown' unless bleu_score

          case bleu_score
          when 0.0..0.3 then 'Poor'
          when 0.3..0.5 then 'Fair'
          when 0.5..0.7 then 'Good'
          when 0.7..0.9 then 'Very Good'
          when 0.9..1.0 then 'Excellent'
          else 'Unknown'
          end
        end

        def to_hash
          {
            original_text: original_text,
            first_translation: first_translation,
            back_translation: back_translation,
            api_type: api_type,
            bleu_score: bleu_score,
            quality_rating: quality_rating,
            timestamp: timestamp
          }
        end
      end
    end
  end
end
