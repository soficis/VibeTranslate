# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TranslationFiesta::Domain::Entities::TranslationResult do
  let(:result) do
    described_class.new(
      original_text: 'Hello world',
      first_translation: 'こんにちは世界',
      back_translation: 'Hello world',
      api_type: :unofficial,
      bleu_score: 0.95
    )
  end

  describe '#quality_rating' do
    it 'returns the correct rating based on BLEU score' do
      expect(result.quality_rating).to eq('Excellent')
    end

    context 'when BLEU score is nil' do
      let(:result) do
        described_class.new(
          original_text: 'Hello',
          first_translation: 'こんにちは',
          back_translation: 'Hello',
          api_type: :unofficial,
          bleu_score: nil
        )
      end

      it 'returns Unknown' do
        expect(result.quality_rating).to eq('Unknown')
      end
    end
  end

  describe '#to_hash' do
    it 'returns a hash representation' do
      hash = result.to_hash
      expect(hash).to include(
        original_text: 'Hello world',
        first_translation: 'こんにちは世界',
        back_translation: 'Hello world',
        api_type: :unofficial,
        bleu_score: 0.95
      )
    end
  end
end
