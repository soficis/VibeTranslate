# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TranslationFiesta::Domain::Services::BleuScorer do
  let(:scorer) { described_class.new }

  describe '#calculate_score' do
    it 'returns 1.0 for identical texts' do
      score = scorer.calculate_score('hello world', 'hello world')
      expect(score).to be_within(0.01).of(1.0)
    end

    it 'returns 0.0 for completely different texts' do
      score = scorer.calculate_score('hello world', 'foo bar baz')
      expect(score).to eq(0.0)
    end

    it 'returns a score between 0 and 1 for similar texts' do
      score = scorer.calculate_score('hello world', 'hello earth')
      expect(score).to be_between(0.0, 1.0)
    end

    it 'handles empty candidate text' do
      score = scorer.calculate_score('hello world', '')
      expect(score).to eq(0.0)
    end

    it 'is case insensitive' do
      score1 = scorer.calculate_score('Hello World', 'hello world')
      score2 = scorer.calculate_score('hello world', 'hello world')
      expect(score1).to eq(score2)
    end
  end
end