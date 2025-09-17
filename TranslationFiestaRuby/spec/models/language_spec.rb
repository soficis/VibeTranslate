require 'spec_helper'
require 'models/language'

RSpec.describe Language do
  describe '#initialize' do
    it 'creates a new language with a name and code' do
      language = Language.new('English', 'en')
      expect(language.name).to eq('English')
      expect(language.code).to eq('en')
    end
  end

  describe '#to_s' do
    it 'returns the name of the language' do
      language = Language.new('Spanish', 'es')
      expect(language.to_s).to eq('Spanish')
    end
  end

  describe '#valid?' do
    it 'returns true for valid language' do
      language = Language.new('French', 'fr')
      expect(language.valid?).to be true
    end

    it 'returns false for invalid language without a name' do
      language = Language.new(nil, 'de')
      expect(language.valid?).to be false
    end

    it 'returns false for invalid language without a code' do
      language = Language.new('German', nil)
      expect(language.valid?).to be false
    end
  end
end