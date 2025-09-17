# frozen_string_literal: true

module TranslationFiesta
  module Domain
    module Repositories
      class CostRepository
        def save_cost_entry(cost_entry)
          raise NotImplementedError, 'Subclasses must implement save_cost_entry'
        end

        def get_monthly_costs(year, month)
          raise NotImplementedError, 'Subclasses must implement get_monthly_costs'
        end

        def get_total_cost_for_period(start_date, end_date)
          raise NotImplementedError, 'Subclasses must implement get_total_cost_for_period'
        end

        def get_cost_breakdown_by_api(year, month)
          raise NotImplementedError, 'Subclasses must implement get_cost_breakdown_by_api'
        end
      end
    end
  end
end