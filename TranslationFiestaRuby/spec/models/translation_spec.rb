require 'spec_helper'
require 'models/translation'

RSpec.describe Translation do
  describe '#initialize' do
    it 'creates a new translation with original text and translated text' do
      translation = Translation.new(original_text: 'Hello', translated_text: 'Hola')
      expect(translation.original_text).to eq('Hello')
      expect(translation.translated_text).to eq('Hola')
    end
  end

  describe '#to_s' do
    it 'returns a string representation of the translation' do
      translation = Translation.new(original_text: 'Hello', translated_text: 'Hola')
      expect(translation.to_s).to eq('Hello -> Hola')
    end
  end

  # Additional tests for other methods related to translations can be added here
end