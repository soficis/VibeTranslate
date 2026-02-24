# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TranslationFiesta::Domain::Entities::TranslationResult do
  let(:result) do
    described_class.new(
      original_text: 'Hello world',
      first_translation: 'こんにちは世界',
      back_translation: 'Hello world',
      api_type: :unofficial
    )
  end

  describe '#to_hash' do
    it 'returns a hash representation' do
      hash = result.to_hash
      expect(hash).to include(
        original_text: 'Hello world',
        first_translation: 'こんにちは世界',
        back_translation: 'Hello world',
        api_type: :unofficial
      )
    end
  end
end
