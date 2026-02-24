# frozen_string_literal: true

require 'sqlite3'

module TranslationFiesta
  module Data
    class DatabaseSetup
      def initialize(memory_db_path = 'translation_memory.db')
        @memory_db_path = memory_db_path
      end

      def create_tables
        create_memory_tables
        puts "Database tables created successfully!"
      end

      private

      def create_memory_tables
        db = SQLite3::Database.new(@memory_db_path)

        db.execute(<<~SQL)
          CREATE TABLE IF NOT EXISTS translation_cache (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cache_key TEXT UNIQUE NOT NULL,
            source_text TEXT NOT NULL,
            from_lang TEXT NOT NULL,
            to_lang TEXT NOT NULL,
            translated_text TEXT NOT NULL,
            expires_at INTEGER NOT NULL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
          )
        SQL

        db.execute('CREATE INDEX IF NOT EXISTS idx_cache_key ON translation_cache(cache_key)')
        db.execute('CREATE INDEX IF NOT EXISTS idx_expires_at ON translation_cache(expires_at)')

        db.close
        puts "Translation memory database initialized."
      end
    end
  end
end
