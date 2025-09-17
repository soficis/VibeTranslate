require 'language_detector'

RSpec.describe LanguageDetector do
  describe '#detect_language' do
    let(:detector) { LanguageDetector.new }

    context 'when given English text' do
      it 'detects the language as English' do
        text = "Hello, how are you?"
        expect(detector.detect_language(text)).to eq('English')
      end
    end

    context 'when given Spanish text' do
      it 'detects the language as Spanish' do
        text = "Hola, ¿cómo estás?"
        expect(detector.detect_language(text)).to eq('Spanish')
      end
    end

    context 'when given French text' do
      it 'detects the language as French' do
        text = "Bonjour, comment ça va?"
        expect(detector.detect_language(text)).to eq('French')
      end
    end

    context 'when given an unknown language' do
      it 'returns nil' do
        text = "This is a test."
        expect(detector.detect_language(text)).to be_nil
      end
    end
  end
end