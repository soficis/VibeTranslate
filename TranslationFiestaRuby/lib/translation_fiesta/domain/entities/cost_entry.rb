# frozen_string_literal: true

module TranslationFiesta
  module Domain
    module Entities
      class CostEntry
        attr_reader :date, :api_type, :character_count, :cost, :operation_type

        def initialize(date:, api_type:, character_count:, cost:, operation_type: 'translation')
          @date = date
          @api_type = api_type
          @character_count = character_count
          @cost = cost
          @operation_type = operation_type
        end

        def month_year
          "#{date.year}-#{date.month.to_s.rjust(2, '0')}"
        end

        def to_hash
          {
            date: date,
            api_type: api_type,
            character_count: character_count,
            cost: cost,
            operation_type: operation_type
          }
        end
      end
    end
  end
end