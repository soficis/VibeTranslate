# frozen_string_literal: true

module TranslationFiesta
  module Features
    class CostTracker
      DEFAULT_MONTHLY_BUDGET = 10.0

      def initialize(cost_repository)
        @cost_repository = cost_repository
        @monthly_budget = DEFAULT_MONTHLY_BUDGET
      end

      attr_accessor :monthly_budget

      def track_translation_cost(cost:, character_count:, api_type:)
        cost_entry = Domain::Entities::CostEntry.new(
          date: Time.now,
          api_type: api_type,
          character_count: character_count,
          cost: cost
        )

        cost_repository.save_cost_entry(cost_entry)
      end

      def get_monthly_summary(year = Time.now.year, month = Time.now.month)
        entries = cost_repository.get_monthly_costs(year, month)
        total_cost = entries.sum(&:cost)
        total_characters = entries.sum(&:character_count)

        {
          total_cost: total_cost,
          total_characters: total_characters,
          budget_remaining: monthly_budget - total_cost,
          budget_used_percentage: (total_cost / monthly_budget * 100).round(2),
          entries_count: entries.length,
          api_breakdown: cost_repository.get_cost_breakdown_by_api(year, month)
        }
      end

      def is_budget_exceeded?(year = Time.now.year, month = Time.now.month)
        monthly_summary = get_monthly_summary(year, month)
        monthly_summary[:total_cost] > monthly_budget
      end

      def get_budget_warning_threshold
        monthly_budget * 0.8 # 80% of budget
      end

      def should_warn_about_budget?(year = Time.now.year, month = Time.now.month)
        monthly_summary = get_monthly_summary(year, month)
        monthly_summary[:total_cost] >= get_budget_warning_threshold
      end

      private

      attr_reader :cost_repository
    end
  end
end