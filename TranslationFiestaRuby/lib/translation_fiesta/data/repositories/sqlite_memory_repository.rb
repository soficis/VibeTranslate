# frozen_string_literal: true

require 'sqlite3'
require 'digest'
require_relative '../../domain/repositories/memory_repository'

module TranslationFiesta
  module Data
    module Repositories
      class SqliteMemoryRepository < TranslationFiesta::Domain::Repositories::MemoryRepository
        def initialize(db_path = 'translation_memory.db')
          @db_path = db_path
          ensure_database_exists
        end

        def get_translation(source_text, from_lang, to_lang)
          cache_key = generate_cache_key(source_text, from_lang, to_lang)
          
          result = db.execute(
            'SELECT translated_text FROM translation_cache WHERE cache_key = ? AND expires_at > ?',
            cache_key,
            Time.now.to_i
          )

          result.first&.first
        end

        def save_translation(source_text, from_lang, to_lang, translated_text)
          cache_key = generate_cache_key(source_text, from_lang, to_lang)
          expires_at = (Time.now + (30 * 24 * 60 * 60)).to_i # 30 days

          db.execute(
            <<~SQL,
              INSERT OR REPLACE INTO translation_cache 
              (cache_key, source_text, from_lang, to_lang, translated_text, expires_at)
              VALUES (?, ?, ?, ?, ?, ?)
            SQL
            cache_key,
            source_text,
            from_lang,
            to_lang,
            translated_text,
            expires_at
          )
        end

        def clear_cache
          db.execute('DELETE FROM translation_cache')
        end

        def cache_size
          result = db.execute('SELECT COUNT(*) FROM translation_cache WHERE expires_at > ?', Time.now.to_i)
          result.first.first
        end

        private

        attr_reader :db_path

        def db
          @db ||= SQLite3::Database.new(db_path)
        end

        def ensure_database_exists
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
        end

        def generate_cache_key(source_text, from_lang, to_lang)
          content = "#{source_text}|#{from_lang}|#{to_lang}"
          Digest::SHA256.hexdigest(content)
        end
      end
    end
  end
end