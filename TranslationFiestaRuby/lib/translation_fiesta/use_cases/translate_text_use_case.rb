# frozen_string_literal: true

module TranslationFiesta
  module UseCases
    class TranslateTextUseCase
      def initialize(translator_service, bleu_scorer = nil)
        @translator_service = translator_service
        @bleu_scorer = bleu_scorer
      end

      def execute(text, api_type = :unofficial)
        result = translator_service.perform_back_translation(text, api_type)
        
        if bleu_scorer
          bleu_score = bleu_scorer.calculate_score(result.original_text, result.back_translation)
          result = enhance_result_with_bleu(result, bleu_score)
        end

        result
      end

      private

      attr_reader :translator_service, :bleu_scorer

      def enhance_result_with_bleu(result, bleu_score)
        Domain::Entities::TranslationResult.new(
          original_text: result.original_text,
          first_translation: result.first_translation,
          back_translation: result.back_translation,
          api_type: result.api_type,
          bleu_score: bleu_score,
          timestamp: result.timestamp
        )
      end
    end
  end
end
