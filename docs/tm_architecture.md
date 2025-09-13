# Translation Memory (TM) System Architecture for TranslationFiesta

## Overview
The Translation Memory system provides intelligent caching for translations across all TranslationFiesta implementations (Python, Go, C#, WinUI/C#, Flutter/Dart). It caches exact and fuzzy-matched translations to improve performance, reduce API calls, and maintain consistency. Key features:
- **Fuzzy Matching**: For similar source texts, suggest best match above a similarity threshold.
- **LRU Eviction**: Least Recently Used entries are evicted when cache exceeds size limit.
- **Configurable Cache Size**: User-settable max entries (default: 1000).
- **Persistence**: Cache saved to JSON file for durability across sessions.
- **Performance Metrics**: Track hit/miss rates, lookup latency, cache utilization.
- **Cache Management**: Clear cache, view/export stats.

This design ensures a consistent interface across languages while using language-native data structures.

## Common Interface
All implementations must expose these methods (adapted to language syntax):

- `init(cache_size: int = 1000, persistence_path: str = "tm_cache.json", similarity_threshold: float = 0.8)`
  - Initializes the TM with config. Loads from persistence if exists.

- `lookup(source: str, target_lang: str) -> str | None`
  - Exact match lookup. Returns cached translation or None. Updates LRU on hit.

- `fuzzy_lookup(source: str, target_lang: str) -> (str, float) | None`
  - Finds best similar translation above threshold. Returns (translation, similarity_score) or None.

- `store(source: str, target_lang: str, translation: str)`
  - Stores new translation. Evicts LRU if full. Updates access time.

- `get_stats() -> dict`
  - Returns metrics: {'hits': int, 'misses': int, 'hit_rate': float, 'avg_lookup_time': float, 'cache_size': int, 'max_size': int}

- `clear_cache()`
  - Clears all entries. Optionally persists empty cache.

- `persist()`
  - Saves cache to file.

- `load_cache()`
  - Loads from file (called in init).

## Fuzzy Matching Algorithm
- Use **Levenshtein Distance** (edit distance) or **difflib.SequenceMatcher** for similarity.
- Similarity score: 1 - (distance / max(len(source), len(cached_source)))
- Threshold: Configurable (default 0.8). Only return if score >= threshold.
- For lookup: Check exact first, then fuzzy on misses.
- Per-language: Source texts grouped by target_lang.

## LRU Eviction
- Track access time on each lookup/store.
- Data structure: Ordered map with move-to-front on access.
  - Python: `collections.OrderedDict` (popitem(last=False) for LRU).
  - Go: `sync.Map` with timestamp map, custom eviction.
  - C#: `Dictionary<string, (Translation, DateTime)>` + sorted list for LRU.
  - Dart: `Map` with `LinkedHashMap` or custom impl.
- Key: f"{source}:{target_lang}" (hashed if needed for large keys).

## Persistence
- Format: JSON file with structure:
  ```json
  {
    "config": {"max_size": 1000, "threshold": 0.8},
    "cache": {
      "en:fr": [{"source": "Hello", "translation": "Bonjour", "access_time": "2025-09-09T02:34:56Z"}]
    },
    "metrics": {"hits": 0, "misses": 0, ...}
  }
  ```
- Load on init, save after store/clear (throttled to avoid I/O overhead).
- Backup on save to prevent corruption.

## Performance Metrics
- Counters: hits, misses (increment on lookup).
- Timers: Measure lookup/store time (e.g., `time.perf_counter()` in Python).
- Computed: hit_rate = hits / (hits + misses), avg_time = total_time / lookups.
- Reset via clear_cache.
- Export: JSON dump or log.

## Integration Guidelines
- In translation services (e.g., translation_services.py, translation_service.go):
  - Before API call: Check TM.lookup() or fuzzy_lookup().
  - On new translation: TM.store().
  - Periodically: Log stats via get_stats().
- Config: Load from settings (e.g., SettingsService.cs).
- Error Handling: Graceful fallback if persistence fails.
- Thread-Safety: Use locks for concurrent access (e.g., in batch processing).

## Language-Specific Notes
- **Python**: Use `rapidfuzz` for fuzzy (faster than difflib). OrderedDict for LRU. JSON via `json` module.
- **Go**: `github.com/ryboe/fuzzy` for matching. Custom LRU with map + heap. JSON via `encoding/json`.
- **C#**: `FuzzySharp` NuGet for matching. ConcurrentDictionary + sorted list. JSON via `System.Text.Json`.
- **Dart/Flutter**: `fuzzywuzzy` package or custom Levenshtein. SplayTreeMap for ordered. JSON via `dart:convert`.
- **WinUI**: Same as C#, integrate with UI for stats display.

## Testing
- Unit: Mock API, test exact/fuzzy hits, eviction, persistence.
- Integration: End-to-end translation with cache.
- Performance: Benchmark lookup times.

## Potential Enhancements
- Multi-provider support (e.g., cache per API like DeepL/Google).
- TMX format import/export for industry standard.
- UI for cache management in WinUI/Flutter.

This architecture ensures scalability and consistency across implementations.