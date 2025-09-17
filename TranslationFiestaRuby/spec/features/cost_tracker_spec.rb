# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TranslationFiesta::Features::CostTracker do
  let(:cost_repository) { double('CostRepository') }
  let(:tracker) { described_class.new(cost_repository) }

  describe '#track_translation_cost' do
    it 'creates and saves a cost entry' do
      expect(cost_repository).to receive(:save_cost_entry) do |entry|
        expect(entry.cost).to eq(0.05)
        expect(entry.character_count).to eq(100)
        expect(entry.api_type).to eq(:official)
      end

      tracker.track_translation_cost(
        cost: 0.05,
        character_count: 100,
        api_type: :official
      )
    end
  end

  describe '#get_monthly_summary' do
    let(:mock_entries) do
      [
        double('CostEntry', cost: 0.05, character_count: 100),
        double('CostEntry', cost: 0.03, character_count: 60)
      ]
    end

    before do
      allow(cost_repository).to receive(:get_monthly_costs).and_return(mock_entries)
      allow(cost_repository).to receive(:get_cost_breakdown_by_api).and_return([])
    end

    it 'returns monthly summary with correct totals' do
      summary = tracker.get_monthly_summary

      expect(summary[:total_cost]).to eq(0.08)
      expect(summary[:total_characters]).to eq(160)
      expect(summary[:budget_remaining]).to eq(9.92)
      expect(summary[:entries_count]).to eq(2)
    end
  end

  describe '#is_budget_exceeded?' do
    before do
      allow(cost_repository).to receive(:get_monthly_costs).and_return([])
      allow(cost_repository).to receive(:get_cost_breakdown_by_api).and_return([])
    end

    it 'returns false when under budget' do
      expect(tracker.is_budget_exceeded?).to be false
    end

    it 'returns true when over budget' do
      tracker.monthly_budget = 0.01
      mock_entries = [double('CostEntry', cost: 0.05, character_count: 100)]
      allow(cost_repository).to receive(:get_monthly_costs).and_return(mock_entries)

      expect(tracker.is_budget_exceeded?).to be true
    end
  end
end