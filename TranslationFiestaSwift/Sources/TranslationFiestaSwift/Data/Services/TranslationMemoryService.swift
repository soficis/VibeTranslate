import Foundation
import Collections
import Logging

/// Translation memory service with LRU eviction.
public actor TranslationMemoryService: TranslationMemoryRepository {
    private let logger = Logger(label: "TranslationMemoryService")
    private let config: TranslationMemoryConfig
    private let fileManager: FileManager

    // LRU cache implementation using OrderedDictionary.
    private var cache: OrderedDictionary<String, TranslationMemoryEntry>

    // Stats properties.
    private var totalHits: Int = 0
    private var totalMisses: Int = 0
    private var totalLookupTime: TimeInterval = 0.0
    private var lookupCount: Int = 0
    private var lastPersistTime: Date? = nil

    private var averageLookupTime: TimeInterval {
        guard lookupCount > 0 else { return 0.0 }
        return totalLookupTime / Double(lookupCount)
    }

    private let persistenceQueue = DispatchQueue(label: "translation-memory-persistence", qos: .utility)
    private var lastAutoSave = Date()

    public init(config: TranslationMemoryConfig, fileManager: FileManager = .default) {
        self.config = config
        self.fileManager = fileManager
        self.cache = OrderedDictionary()

        // Load existing cache on initialization (non-blocking).
        Task.detached(priority: .background) { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 100_000_000)
                try await self?.loadFromPersistence()
            } catch {
                await self?.logDebug("Translation memory initialization failed: \(error.localizedDescription)")
            }
        }
    }

    private func logDebug(_ message: String) {
        logger.debug("\(message)")
    }

    // MARK: - TranslationMemoryRepository

    public func lookupExact(
        sourceText: String,
        sourceLanguage: Language,
        targetLanguage: Language
    ) async throws -> TranslationMemoryEntry? {
        let startTime = CFAbsoluteTimeGetCurrent()
        let cacheKey = createCacheKey(sourceText, sourceLanguage, targetLanguage)

        if var entry = cache[cacheKey] {
            // Move to end (most recently used).
            cache.removeValue(forKey: cacheKey)
            entry.recordAccess()
            cache[cacheKey] = entry

            recordHit(lookupTime: CFAbsoluteTimeGetCurrent() - startTime)
            logger.debug("Cache hit", metadata: ["key": "\(cacheKey)"])

            return entry
        }

        recordMiss(lookupTime: CFAbsoluteTimeGetCurrent() - startTime)
        logger.debug("Cache miss", metadata: ["key": "\(cacheKey)"])
        return nil
    }

    public func store(_ entry: TranslationMemoryEntry) async throws {
        let cacheKey = entry.cacheKey

        // Check if we need to evict (LRU).
        if cache.count >= config.maxCacheSize && cache[cacheKey] == nil {
            evictLeastRecentlyUsed()
        }

        // Remove existing entry if present (to update position).
        cache.removeValue(forKey: cacheKey)

        // Add/update entry at the end (most recently used).
        cache[cacheKey] = entry

        logger.debug("Entry stored", metadata: [
            "key": "\(cacheKey)",
            "cacheSize": "\(cache.count)"
        ])

        scheduleAutoSave()
    }

    public func getStats() async throws -> TranslationMemoryStats {
        TranslationMemoryStats(
            totalEntries: cache.count,
            maxCacheSize: config.maxCacheSize,
            totalHits: totalHits,
            totalMisses: totalMisses,
            averageLookupTime: averageLookupTime,
            lastPersistTime: lastPersistTime
        )
    }

    public func clearMemory() async throws {
        cache.removeAll()
        totalHits = 0
        totalMisses = 0
        totalLookupTime = 0.0
        lookupCount = 0
        lastPersistTime = nil
        try await persist()

        logger.info("Translation memory cleared")
    }

    public func persist() async throws {
        // Capture current state values.
        let entries = Array(cache.values)
        let stats = TranslationMemoryPersistentStats(
            totalHits: totalHits,
            totalMisses: totalMisses,
            totalLookupTime: totalLookupTime,
            lookupCount: lookupCount,
            lastPersistTime: Date()
        )
        let persistenceURL = getPersistenceURL()
        let logger = self.logger

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            persistenceQueue.async {
                let fileManager = FileManager.default
                do {
                    let backupURL = persistenceURL.appendingPathExtension("backup")
                    if fileManager.fileExists(atPath: persistenceURL.path) {
                        _ = try? fileManager.replaceItem(
                            at: backupURL,
                            withItemAt: persistenceURL,
                            backupItemName: nil,
                            options: [],
                            resultingItemURL: nil
                        )
                    }

                    let container = TranslationMemoryContainer(entries: entries, stats: stats)
                    let data = try JSONEncoder().encode(container)
                    try data.write(to: persistenceURL)

                    logger.debug("Translation memory saved", metadata: [
                        "entries": "\(entries.count)",
                        "size": "\(data.count) bytes",
                        "hits": "\(stats.totalHits)",
                        "misses": "\(stats.totalMisses)"
                    ])

                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        lastPersistTime = Date()
    }

    // MARK: - Private methods

    private func createCacheKey(_ sourceText: String, _ sourceLanguage: Language, _ targetLanguage: Language) -> String {
        "\(sourceText):\(sourceLanguage.rawValue):\(targetLanguage.rawValue)"
    }

    private func evictLeastRecentlyUsed() {
        guard let firstKey = cache.keys.first else { return }
        cache.removeValue(forKey: firstKey)
        logger.debug("LRU eviction", metadata: ["evictedKey": "\(firstKey)"])
    }

    private func scheduleAutoSave() {
        let now = Date()
        if now.timeIntervalSince(lastAutoSave) >= config.autoSaveInterval {
            lastAutoSave = now
            Task {
                try? await persist()
            }
        }
    }

    private func loadFromPersistence() async throws {
        let url = getPersistenceURL()

        guard fileManager.fileExists(atPath: url.path) else {
            logger.info("No existing translation memory file found")
            return
        }

        let data = try Data(contentsOf: url)
        let container = try JSONDecoder().decode(TranslationMemoryContainer.self, from: data)

        // Reconstruct cache maintaining LRU order.
        cache.removeAll()
        for entry in container.entries.sorted(by: { $0.accessTime < $1.accessTime }) {
            cache[entry.cacheKey] = entry
        }

        totalHits = container.stats.totalHits
        totalMisses = container.stats.totalMisses
        totalLookupTime = container.stats.totalLookupTime
        lookupCount = container.stats.lookupCount
        lastPersistTime = container.stats.lastPersistTime

        logger.info("Translation memory loaded", metadata: [
            "entries": "\(cache.count)",
            "hits": "\(totalHits)",
            "misses": "\(totalMisses)"
        ])
    }

    private func getPersistenceURL() -> URL {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent(config.persistencePath)
    }

    // MARK: - Stats helpers

    private func recordHit(lookupTime: TimeInterval) {
        totalHits += 1
        recordLookupTime(lookupTime)
    }

    private func recordMiss(lookupTime: TimeInterval) {
        totalMisses += 1
        recordLookupTime(lookupTime)
    }

    private func recordLookupTime(_ time: TimeInterval) {
        totalLookupTime += time
        lookupCount += 1
    }
}

// MARK: - Supporting Types

private struct TranslationMemoryContainer: Codable {
    let entries: [TranslationMemoryEntry]
    let stats: TranslationMemoryPersistentStats
}

private struct TranslationMemoryPersistentStats: Codable {
    let totalHits: Int
    let totalMisses: Int
    let totalLookupTime: TimeInterval
    let lookupCount: Int
    let lastPersistTime: Date?
}
