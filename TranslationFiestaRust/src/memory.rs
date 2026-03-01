use std::path::{Path, PathBuf};
use std::time::Instant;

use anyhow::{Context, Result};
use chrono::{DateTime, Utc};
use rusqlite::{Connection, OptionalExtension, params};

use crate::models::{MemoryEntry, MemoryStats};

#[derive(Debug, Clone)]
pub struct TranslationMemory {
    db_path: PathBuf,
    max_entries: usize,
}

impl TranslationMemory {
    pub fn new(db_path: &Path, max_entries: usize) -> Result<Self> {
        let memory = Self {
            db_path: db_path.to_path_buf(),
            max_entries,
        };
        memory.init_schema()?;
        Ok(memory)
    }

    pub fn max_entries(&self) -> usize {
        self.max_entries
    }

    pub fn lookup(
        &self,
        source_text: &str,
        source_language: &str,
        target_language: &str,
        provider_id: &str,
    ) -> Result<Option<String>> {
        let started_at = Instant::now();
        let key = cache_key(source_text, source_language, target_language, provider_id);
        let now = Utc::now().to_rfc3339();

        let conn = self.connection()?;
        let maybe_translation: Option<String> = conn
            .query_row(
                "SELECT translated_text FROM translation_cache WHERE cache_key = ?1",
                params![key],
                |row| row.get(0),
            )
            .optional()
            .context("failed to query translation memory")?;

        if maybe_translation.is_some() {
            conn.execute(
                "UPDATE translation_cache
                 SET access_count = access_count + 1,
                     last_accessed = ?1
                 WHERE cache_key = ?2",
                params![
                    now,
                    cache_key(source_text, source_language, target_language, provider_id)
                ],
            )
            .context("failed to update translation memory access info")?;
            self.bump_metrics(&conn, true, started_at.elapsed().as_secs_f64() * 1000.0)?;
        } else {
            self.bump_metrics(&conn, false, started_at.elapsed().as_secs_f64() * 1000.0)?;
        }

        Ok(maybe_translation)
    }

    pub fn store(
        &self,
        source_text: &str,
        translated_text: &str,
        source_language: &str,
        target_language: &str,
        provider_id: &str,
    ) -> Result<()> {
        let now = Utc::now().to_rfc3339();
        let key = cache_key(source_text, source_language, target_language, provider_id);

        let conn = self.connection()?;
        conn.execute(
            "INSERT INTO translation_cache (
                cache_key,
                source_text,
                translated_text,
                source_language,
                target_language,
                provider_id,
                access_count,
                created_at,
                last_accessed
             ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, 1, ?7, ?7)
             ON CONFLICT(cache_key) DO UPDATE SET
                translated_text = excluded.translated_text,
                access_count = translation_cache.access_count + 1,
                last_accessed = excluded.last_accessed",
            params![
                key,
                source_text,
                translated_text,
                source_language,
                target_language,
                provider_id,
                now,
            ],
        )
        .context("failed to store translation memory entry")?;

        self.prune_oldest(&conn)?;

        Ok(())
    }

    pub fn search(&self, query: &str, limit: usize) -> Result<Vec<MemoryEntry>> {
        let conn = self.connection()?;

        let escaped_query = query
            .trim()
            .replace('\\', "\\\\")
            .replace('%', "\\%")
            .replace('_', "\\_");
        let like_query = format!("%{}%", escaped_query);
        let mut statement = conn.prepare(
            "SELECT source_text, translated_text, source_language, target_language, provider_id, access_count, last_accessed
             FROM translation_cache
             WHERE source_text LIKE ?1 ESCAPE '\\' OR translated_text LIKE ?1 ESCAPE '\\'
             ORDER BY last_accessed DESC
             LIMIT ?2",
        )?;

        let rows = statement.query_map(params![like_query, limit as i64], |row| {
            let last_accessed_raw: String = row.get(6)?;
            let last_accessed = DateTime::parse_from_rfc3339(&last_accessed_raw)
                .map(|dt| dt.with_timezone(&Utc))
                .unwrap_or_else(|_| Utc::now());

            Ok(MemoryEntry {
                source_text: row.get(0)?,
                translated_text: row.get(1)?,
                source_language: row.get(2)?,
                target_language: row.get(3)?,
                provider_id: row.get(4)?,
                access_count: row.get(5)?,
                last_accessed,
            })
        })?;

        let mut entries = Vec::new();
        for item in rows {
            entries.push(item?);
        }

        Ok(entries)
    }

    pub fn clear(&self) -> Result<()> {
        let conn = self.connection()?;
        conn.execute("DELETE FROM translation_cache", [])
            .context("failed to clear translation cache")?;
        conn.execute(
            "UPDATE memory_metrics
             SET hits = 0,
                 misses = 0,
                 total_lookups = 0,
                 total_lookup_time_ms = 0.0,
                 last_persisted = ?1
             WHERE id = 1",
            params![Utc::now().to_rfc3339()],
        )
        .context("failed to clear memory metrics")?;

        Ok(())
    }

    pub fn stats(&self) -> Result<MemoryStats> {
        let conn = self.connection()?;

        let total_entries: usize = conn
            .query_row("SELECT COUNT(*) FROM translation_cache", [], |row| {
                let value: i64 = row.get(0)?;
                Ok(value as usize)
            })
            .context("failed to count translation memory entries")?;

        let (hits, misses, total_lookups, total_lookup_time_ms): (i64, i64, i64, f64) = conn
            .query_row(
                "SELECT hits, misses, total_lookups, total_lookup_time_ms
                 FROM memory_metrics
                 WHERE id = 1",
                [],
                |row| Ok((row.get(0)?, row.get(1)?, row.get(2)?, row.get(3)?)),
            )
            .context("failed to load memory metrics")?;

        let total_lookups_usize = total_lookups.max(0) as usize;
        let hit_rate = if total_lookups_usize > 0 {
            hits.max(0) as f64 / total_lookups_usize as f64
        } else {
            0.0
        };

        let avg_lookup_ms = if total_lookups_usize > 0 {
            total_lookup_time_ms / total_lookups_usize as f64
        } else {
            0.0
        };

        Ok(MemoryStats {
            total_entries,
            max_entries: self.max_entries,
            total_hits: hits.max(0) as usize,
            total_misses: misses.max(0) as usize,
            total_lookups: total_lookups_usize,
            hit_rate,
            avg_lookup_ms,
        })
    }

    fn init_schema(&self) -> Result<()> {
        let conn = self.connection()?;

        conn.execute_batch(
            "CREATE TABLE IF NOT EXISTS translation_cache (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                cache_key TEXT UNIQUE NOT NULL,
                source_text TEXT NOT NULL,
                translated_text TEXT NOT NULL,
                source_language TEXT NOT NULL,
                target_language TEXT NOT NULL,
                provider_id TEXT NOT NULL,
                access_count INTEGER NOT NULL DEFAULT 1,
                created_at TEXT NOT NULL,
                last_accessed TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_cache_key ON translation_cache(cache_key);
            CREATE INDEX IF NOT EXISTS idx_last_accessed ON translation_cache(last_accessed);
            CREATE TABLE IF NOT EXISTS memory_metrics (
                id INTEGER PRIMARY KEY CHECK(id = 1),
                hits INTEGER NOT NULL DEFAULT 0,
                misses INTEGER NOT NULL DEFAULT 0,
                total_lookups INTEGER NOT NULL DEFAULT 0,
                total_lookup_time_ms REAL NOT NULL DEFAULT 0.0,
                last_persisted TEXT
            );",
        )
        .context("failed to initialize translation memory schema")?;

        conn.execute(
            "INSERT OR IGNORE INTO memory_metrics (id, hits, misses, total_lookups, total_lookup_time_ms, last_persisted)
             VALUES (1, 0, 0, 0, 0.0, ?1)",
            params![Utc::now().to_rfc3339()],
        )
        .context("failed to initialize memory metrics row")?;

        self.prune_oldest(&conn)?;

        Ok(())
    }

    fn bump_metrics(&self, conn: &Connection, hit: bool, lookup_ms: f64) -> Result<()> {
        if hit {
            conn.execute(
                "UPDATE memory_metrics
                 SET hits = hits + 1,
                     total_lookups = total_lookups + 1,
                     total_lookup_time_ms = total_lookup_time_ms + ?1,
                     last_persisted = ?2
                 WHERE id = 1",
                params![lookup_ms, Utc::now().to_rfc3339()],
            )?;
        } else {
            conn.execute(
                "UPDATE memory_metrics
                 SET misses = misses + 1,
                     total_lookups = total_lookups + 1,
                     total_lookup_time_ms = total_lookup_time_ms + ?1,
                     last_persisted = ?2
                 WHERE id = 1",
                params![lookup_ms, Utc::now().to_rfc3339()],
            )?;
        }
        Ok(())
    }

    fn prune_oldest(&self, conn: &Connection) -> Result<()> {
        let current_size: usize = conn
            .query_row("SELECT COUNT(*) FROM translation_cache", [], |row| {
                let value: i64 = row.get(0)?;
                Ok(value as usize)
            })
            .context("failed to count translation cache entries")?;

        if current_size <= self.max_entries {
            return Ok(());
        }

        let overflow = current_size - self.max_entries;
        conn.execute(
            "DELETE FROM translation_cache
             WHERE id IN (
                SELECT id FROM translation_cache
                ORDER BY last_accessed ASC
                LIMIT ?1
             )",
            params![overflow as i64],
        )
        .context("failed to prune translation memory")?;

        Ok(())
    }

    fn connection(&self) -> Result<Connection> {
        if let Some(parent) = self.db_path.parent() {
            std::fs::create_dir_all(parent).with_context(|| {
                format!(
                    "failed to create translation memory directory {}",
                    parent.display()
                )
            })?;
        }

        Connection::open(&self.db_path)
            .with_context(|| format!("failed to open sqlite db {}", self.db_path.display()))
    }
}

fn cache_key(
    source_text: &str,
    source_language: &str,
    target_language: &str,
    provider_id: &str,
) -> String {
    format!(
        "{}:{}:{}:{}",
        provider_id, source_language, target_language, source_text
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn stores_and_reads_translation_entries() {
        let temp_dir = TempDir::new().unwrap();
        let db_path = temp_dir.path().join("memory.db");
        let memory = TranslationMemory::new(&db_path, 100).unwrap();

        memory
            .store("hello", "こんにちは", "en", "ja", "google_unofficial")
            .unwrap();
        let hit = memory
            .lookup("hello", "en", "ja", "google_unofficial")
            .unwrap();

        assert_eq!(hit.as_deref(), Some("こんにちは"));

        let stats = memory.stats().unwrap();
        assert_eq!(stats.total_entries, 1);
        assert_eq!(stats.total_hits, 1);
    }
}
