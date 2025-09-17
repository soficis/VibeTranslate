# frozen_string_literal: true

require 'sqlite3'
require_relative '../../domain/repositories/cost_repository'

module TranslationFiesta
  module Data
    module Repositories
      class SqliteCostRepository < TranslationFiesta::Domain::Repositories::CostRepository
        def initialize(db_path = 'translation_fiesta.db')
          @db_path = db_path
          ensure_database_exists
        end

        def save_cost_entry(cost_entry)
          db.execute(
            <<~SQL,
              INSERT INTO cost_entries (date, api_type, character_count, cost, operation_type)
              VALUES (?, ?, ?, ?, ?)
            SQL
            cost_entry.date.strftime('%Y-%m-%d %H:%M:%S'),
            cost_entry.api_type.to_s,
            cost_entry.character_count,
            cost_entry.cost,
            cost_entry.operation_type
          )
        end

        def get_monthly_costs(year, month)
          start_date = Date.new(year, month, 1)
          end_date = start_date.next_month - 1

          rows = db.execute(
            <<~SQL,
              SELECT date, api_type, character_count, cost, operation_type
              FROM cost_entries
              WHERE date BETWEEN ? AND ?
              ORDER BY date DESC
            SQL
            start_date.strftime('%Y-%m-%d'),
            end_date.strftime('%Y-%m-%d 23:59:59')
          )

          rows.map { |row| row_to_cost_entry(row) }
        end

        def get_total_cost_for_period(start_date, end_date)
          result = db.execute(
            <<~SQL,
              SELECT SUM(cost) as total_cost
              FROM cost_entries
              WHERE date BETWEEN ? AND ?
            SQL
            start_date.strftime('%Y-%m-%d'),
            end_date.strftime('%Y-%m-%d 23:59:59')
          )

          result.first&.first || 0.0
        end

        def get_cost_breakdown_by_api(year, month)
          start_date = Date.new(year, month, 1)
          end_date = start_date.next_month - 1

          rows = db.execute(
            <<~SQL,
              SELECT api_type, SUM(cost) as total_cost, SUM(character_count) as total_characters
              FROM cost_entries
              WHERE date BETWEEN ? AND ?
              GROUP BY api_type
            SQL
            start_date.strftime('%Y-%m-%d'),
            end_date.strftime('%Y-%m-%d 23:59:59')
          )

          rows.map do |row|
            {
              api_type: row[0],
              total_cost: row[1],
              total_characters: row[2]
            }
          end
        end

        private

        attr_reader :db_path

        def db
          @db ||= SQLite3::Database.new(db_path)
        end

        def ensure_database_exists
          db.execute(<<~SQL)
            CREATE TABLE IF NOT EXISTS cost_entries (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              date TEXT NOT NULL,
              api_type TEXT NOT NULL,
              character_count INTEGER NOT NULL,
              cost REAL NOT NULL,
              operation_type TEXT DEFAULT 'translation',
              created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
          SQL
        end

        def row_to_cost_entry(row)
          Domain::Entities::CostEntry.new(
            date: DateTime.parse(row[0]),
            api_type: row[1].to_sym,
            character_count: row[2],
            cost: row[3],
            operation_type: row[4]
          )
        end
      end
    end
  end
end