import Foundation
import Collections
import Logging

/// Translation memory service with LRU eviction and fuzzy matching
/// Following Clean Code: meaningful names and clear intent
public final class TranslationMemoryService: TranslationMemoryRepository {
    private let logger = Logger(label: "TranslationMemoryService")
    private let config: TranslationMemoryConfig
    private let fileManager: FileManager
    
    // LRU cache implementation using OrderedDictionary
    private var cache: OrderedDictionary<String, TranslationMemoryEntry>
    private var stats: TranslationMemoryInternalStats
    private let persistenceQueue = DispatchQueue(label: "translation-memory-persistence", qos: .utility)
    
    public init(config: TranslationMemoryConfig, fileManager: FileManager = .default) {
        self.config = config
        self.fileManager = fileManager
        self.cache = OrderedDictionary()
        self.stats = TranslationMemoryInternalStats()
        
        // Load existing cache on initialization (non-blocking)
        Task.detached(priority: .background) { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 100_000_000) // Small delay to let app start
                try await self?.loadFromPersistence()
            } catch {
                // Silently handle initialization errors
                self?.logger.debug("Translation memory initialization failed: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - TranslationMemoryRepository Implementation
    
    public func lookupExact(
        sourceText: String,
        sourceLanguage: Language,
        targetLanguage: Language
    ) async throws -> TranslationMemoryEntry? {
        let startTime = CFAbsoluteTimeGetCurrent()
        let cacheKey = createCacheKey(sourceText, sourceLanguage, targetLanguage)
        
        if var entry = cache[cacheKey] {
            // Move to end (most recently used)
            cache.removeValue(forKey: cacheKey)
            entry.recordAccess()
            cache[cacheKey] = entry
            
            stats.recordHit(lookupTime: CFAbsoluteTimeGetCurrent() - startTime)
            logger.debug("Cache hit", metadata: ["key": "\(cacheKey)"])
            
            return entry
        } else {
            stats.recordMiss(lookupTime: CFAbsoluteTimeGetCurrent() - startTime)
            logger.debug("Cache miss", metadata: ["key": "\(cacheKey)"])
            
            return nil
        }
    }
    
    public func lookupFuzzy(
        sourceText: String,
        sourceLanguage: Language,
        targetLanguage: Language,
        threshold: Double
    ) async throws -> [FuzzyMatch] {
        guard config.enableFuzzyMatching else { return [] }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        var matches: [FuzzyMatch] = []
        
        // Find entries with matching language pair
        let languagePairEntries = cache.values.filter {
            $0.sourceLanguage == sourceLanguage && $0.targetLanguage == targetLanguage
        }
        
        for entry in languagePairEntries {
            let similarity = calculateSimilarity(sourceText, entry.sourceText)
            let distance = levenshteinDistance(sourceText, entry.sourceText)
            
            if similarity >= threshold {
                let match = FuzzyMatch(
                    entry: entry,
                    similarityScore: similarity,
                    levenshteinDistance: distance
                )
                matches.append(match)
            }
        }
        
        // Sort by similarity score (highest first)
        matches.sort { $0.similarityScore > $1.similarityScore }
        
        if !matches.isEmpty {
            stats.recordFuzzyHit()
            logger.debug("Fuzzy matches found", metadata: [
                "count": "\(matches.count)",
                "bestScore": "\(matches.first?.similarityScore ?? 0)"
            ])
        }
        
        stats.recordLookupTime(CFAbsoluteTimeGetCurrent() - startTime)
        
        return matches
    }
    
    public func store(_ entry: TranslationMemoryEntry) async throws {
        let cacheKey = entry.cacheKey
        
        // Check if we need to evict (LRU)
        if cache.count >= config.maxCacheSize && cache[cacheKey] == nil {
            evictLeastRecentlyUsed()
        }
        
        // Remove existing entry if present (to update position)
        cache.removeValue(forKey: cacheKey)
        
        // Add/update entry at the end (most recently used)
        cache[cacheKey] = entry
        
        logger.debug("Entry stored", metadata: [
            "key": "\(cacheKey)",
            "cacheSize": "\(cache.count)"
        ])
        
        // Auto-save if interval has passed
        scheduleAutoSave()
    }
    
    public func getStats() async throws -> TranslationMemoryStats {
        return TranslationMemoryStats(
            totalEntries: cache.count,
            maxCacheSize: config.maxCacheSize,
            totalHits: stats.totalHits,
            totalMisses: stats.totalMisses,
            fuzzyHits: stats.fuzzyHits,
            averageLookupTime: stats.averageLookupTime,
            lastPersistTime: stats.lastPersistTime
        )
    }
    
    public func clearMemory() async throws {
        cache.removeAll()
        stats = TranslationMemoryInternalStats()
        try await persist()
        
        logger.info("Translation memory cleared")
    }
    
    public func persist() async throws {
        // Capture current state to avoid Sendable issues
        let currentCache = cache
        let currentStats = stats
        let persistenceURL = getPersistenceURL()
        let logger = self.logger

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            persistenceQueue.async {
                let fileManager = FileManager.default
                do {
                    let url = persistenceURL
                    
                    // Create backup of existing file
                    let backupURL = url.appendingPathExtension("backup")
                    if fileManager.fileExists(atPath: url.path) {
                        _ = try? fileManager.replaceItem(at: backupURL, withItemAt: url, backupItemName: nil, options: [], resultingItemURL: nil)
                    }
                    
                    let container = TranslationMemoryContainer(
                        entries: Array(currentCache.values),
                        stats: TranslationMemoryPersistentStats(
                            totalHits: currentStats.totalHits,
                            totalMisses: currentStats.totalMisses,
                            fuzzyHits: currentStats.fuzzyHits,
                            totalLookupTime: currentStats.totalLookupTime,
                            lookupCount: currentStats.lookupCount,
                            lastPersistTime: Date()
                        )
                    )
                    
                    let data = try JSONEncoder().encode(container)
                    try data.write(to: url)
                    
                    logger.debug("Translation memory saved", metadata: [
                        "entries": "\(currentCache.count)",
                        "size": "\(data.count) bytes",
                        "hits": "\(currentStats.totalHits)",
                        "misses": "\(currentStats.totalMisses)"
                    ])
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        
        // Update stats after successful persistence
        stats.lastPersistTime = Date()
    }
    
    // MARK: - Private Methods
    
    private func createCacheKey(_ sourceText: String, _ sourceLanguage: Language, _ targetLanguage: Language) -> String {
        return "\(sourceText):\(sourceLanguage.rawValue):\(targetLanguage.rawValue)"
    }
    
    private func evictLeastRecentlyUsed() {
        guard let firstKey = cache.keys.first else { return }
        cache.removeValue(forKey: firstKey)
        
        logger.debug("LRU eviction", metadata: ["evictedKey": "\(firstKey)"])
    }
    
    private func calculateSimilarity(_ text1: String, _ text2: String) -> Double {
        guard !text1.isEmpty && !text2.isEmpty else { return 0.0 }
        
        let distance = levenshteinDistance(text1, text2)
        let maxLength = max(text1.count, text2.count)
        
        return 1.0 - (Double(distance) / Double(maxLength))
    }
    
    private func levenshteinDistance(_ str1: String, _ str2: String) -> Int {
        let arr1 = Array(str1)
        let arr2 = Array(str2)
        let len1 = arr1.count
        let len2 = arr2.count
        
        if len1 == 0 { return len2 }
        if len2 == 0 { return len1 }
        
        var matrix = Array(repeating: Array(repeating: 0, count: len2 + 1), count: len1 + 1)
        
        for i in 0...len1 {
            matrix[i][0] = i
        }
        
        for j in 0...len2 {
            matrix[0][j] = j
        }
        
        for i in 1...len1 {
            for j in 1...len2 {
                let cost = arr1[i - 1] == arr2[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,      // deletion
                    matrix[i][j - 1] + 1,      // insertion
                    matrix[i - 1][j - 1] + cost // substitution
                )
            }
        }
        
        return matrix[len1][len2]
    }
    
    private var lastAutoSave = Date()
    
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
        
        // Reconstruct cache maintaining LRU order
        cache.removeAll()
        for entry in container.entries.sorted(by: { $0.accessTime < $1.accessTime }) {
            cache[entry.cacheKey] = entry
        }
        
        // Restore stats
        stats.totalHits = container.stats.totalHits
        stats.totalMisses = container.stats.totalMisses
        stats.fuzzyHits = container.stats.fuzzyHits
        stats.totalLookupTime = container.stats.totalLookupTime
        stats.lookupCount = container.stats.lookupCount
        stats.lastPersistTime = container.stats.lastPersistTime
        
        logger.info("Translation memory loaded", metadata: [
            "entries": "\(cache.count)",
            "hits": "\(stats.totalHits)",
            "misses": "\(stats.totalMisses)"
        ])
    }
    
    private func saveToPersistence() throws {
        let url = getPersistenceURL()
        
        // Create backup of existing file
        let backupURL = url.appendingPathExtension("backup")
        if fileManager.fileExists(atPath: url.path) {
            _ = try? fileManager.replaceItem(at: backupURL, withItemAt: url, backupItemName: nil, options: [], resultingItemURL: nil)
        }
        
        let container = TranslationMemoryContainer(
            entries: Array(cache.values),
            stats: TranslationMemoryPersistentStats(
                totalHits: stats.totalHits,
                totalMisses: stats.totalMisses,
                fuzzyHits: stats.fuzzyHits,
                totalLookupTime: stats.totalLookupTime,
                lookupCount: stats.lookupCount,
                lastPersistTime: Date()
            )
        )
        
        let data = try JSONEncoder().encode(container)
        try data.write(to: url)
        
        logger.info("Translation memory saved", metadata: [
            "entries": "\(cache.count)",
            "size": "\(data.count) bytes"
        ])
    }
    
    private func getPersistenceURL() -> URL {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent(config.persistencePath)
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
    let fuzzyHits: Int
    let totalLookupTime: TimeInterval
    let lookupCount: Int
    let lastPersistTime: Date?
}

private class TranslationMemoryInternalStats {
    var totalHits: Int = 0
    var totalMisses: Int = 0
    var fuzzyHits: Int = 0
    var totalLookupTime: TimeInterval = 0.0
    var lookupCount: Int = 0
    var lastPersistTime: Date? = nil
    
    var averageLookupTime: TimeInterval {
        guard lookupCount > 0 else { return 0.0 }
        return totalLookupTime / Double(lookupCount)
    }
    
    func recordHit(lookupTime: TimeInterval) {
        totalHits += 1
        recordLookupTime(lookupTime)
    }
    
    func recordMiss(lookupTime: TimeInterval) {
        totalMisses += 1
        recordLookupTime(lookupTime)
    }
    
    func recordFuzzyHit() {
        fuzzyHits += 1
    }
    
    func recordLookupTime(_ time: TimeInterval) {
        totalLookupTime += time
        lookupCount += 1
    }
}