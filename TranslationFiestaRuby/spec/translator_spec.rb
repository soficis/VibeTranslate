require 'translator'

RSpec.describe Translator do
  describe '#translate' do
    context 'when given valid input' do
      it 'translates text from English to Spanish' do
        translator = Translator.new
        result = translator.translate('Hello', 'English', 'Spanish')
        expect(result).to eq('Hola')
      end

      it 'translates text from Spanish to English' do
        translator = Translator.new
        result = translator.translate('Hola', 'Spanish', 'English')
        expect(result).to eq('Hello')
      end
    end

    context 'when given invalid input' do
      it 'raises an error for unsupported languages' do
        translator = Translator.new
        expect {
          translator.translate('Hello', 'English', 'Klingon')
        }.to raise_error(ArgumentError, 'Unsupported language: Klingon')
      end

      it 'raises an error for empty text' do
        translator = Translator.new
        expect {
          translator.translate('', 'English', 'Spanish')
        }.to raise_error(ArgumentError, 'Text cannot be empty')
      end
    end
  end
end