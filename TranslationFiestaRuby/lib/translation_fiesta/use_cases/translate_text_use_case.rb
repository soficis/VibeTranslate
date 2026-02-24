# frozen_string_literal: true

module TranslationFiesta
  module UseCases
    class TranslateTextUseCase
      def initialize(translator_service)
        @translator_service = translator_service
      end

      def execute(text, api_type = :unofficial)
        translator_service.perform_back_translation(text, api_type)
      end

      private

      attr_reader :translator_service
    end
  end
end
