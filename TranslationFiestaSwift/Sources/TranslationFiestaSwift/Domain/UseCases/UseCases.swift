import Foundation

/// Use case for performing back-translations
/// Following Clean Code: single responsibility principle
public final class BackTranslationUseCase {
    private let translationRepository: TranslationRepository
    private let costTrackingRepository: CostTrackingRepository
    private let translationMemoryRepository: TranslationMemoryRepository
    private let qualityRepository: QualityRepository
    
    public init(
        translationRepository: TranslationRepository,
        costTrackingRepository: CostTrackingRepository,
        translationMemoryRepository: TranslationMemoryRepository,
        qualityRepository: QualityRepository
    ) {
        self.translationRepository = translationRepository
        self.costTrackingRepository = costTrackingRepository
        self.translationMemoryRepository = translationMemoryRepository
        self.qualityRepository = qualityRepository
    }
    
    /// Execute back-translation with memory and cost tracking
    public func execute(
        text: String,
        sourceLanguage: Language,
        targetLanguage: Language,
        apiProvider: APIProvider
    ) async throws -> BackTranslationResult {
        // Check translation memory first
        if let cachedResult = try await checkTranslationMemory(
            text: text,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        ) {
            return cachedResult
        }
        
        // Perform the actual back-translation
        let result = try await translationRepository.backTranslate(
            text: text,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            apiProvider: apiProvider
        )
        
        // Track costs if applicable
        if apiProvider.hasCostTracking {
            try await trackTranslationCosts(result: result, apiProvider: apiProvider)
        }
        
        // Store in translation memory
        try await storeInTranslationMemory(result: result)
        
        return result
    }
    
    private func checkTranslationMemory(
        text: String,
        sourceLanguage: Language,
        targetLanguage: Language
    ) async throws -> BackTranslationResult? {
        // Check for exact match first
        if let exactMatch = try await translationMemoryRepository.lookupExact(
            sourceText: text,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        ) {
            return try await createResultFromMemoryEntry(exactMatch)
        }
        
        // Check for fuzzy matches
        let fuzzyMatches = try await translationMemoryRepository.lookupFuzzy(
            sourceText: text,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            threshold: 0.9 // High threshold for back-translation
        )
        
        if let bestMatch = fuzzyMatches.first, bestMatch.similarityScore > 0.95 {
            return try await createResultFromMemoryEntry(bestMatch.entry)
        }
        
        return nil
    }
    
    private func createResultFromMemoryEntry(_ entry: TranslationMemoryEntry) async throws -> BackTranslationResult {
        // This is simplified - in a real implementation, we'd need to store
        // the complete back-translation result in memory
        throw TranslationError.notImplemented("Memory-based result creation not implemented")
    }
    
    private func trackTranslationCosts(
        result: BackTranslationResult,
        apiProvider: APIProvider
    ) async throws {
        try await costTrackingRepository.trackCost(
            CostEntry(
                characterCount: result.forwardTranslation.originalText.count,
                costUSD: result.totalCost.costInUSD,
                sourceLanguage: result.forwardTranslation.sourceLanguage,
                targetLanguage: result.forwardTranslation.targetLanguage,
                apiProvider: apiProvider
            )
        )
    }
    
    private func storeInTranslationMemory(result: BackTranslationResult) async throws {
        // Store forward translation
        let forwardEntry = TranslationMemoryEntry(
            sourceText: result.forwardTranslation.originalText,
            translatedText: result.forwardTranslation.translatedText,
            sourceLanguage: result.forwardTranslation.sourceLanguage,
            targetLanguage: result.forwardTranslation.targetLanguage
        )
        try await translationMemoryRepository.store(forwardEntry)
        
        // Store backward translation
        let backwardEntry = TranslationMemoryEntry(
            sourceText: result.backwardTranslation.originalText,
            translatedText: result.backwardTranslation.translatedText,
            sourceLanguage: result.backwardTranslation.sourceLanguage,
            targetLanguage: result.backwardTranslation.targetLanguage
        )
        try await translationMemoryRepository.store(backwardEntry)
    }
}

/// Use case for batch processing files
public final class BatchProcessingUseCase {
    private let fileRepository: FileRepository
    private let batchRepository: BatchRepository
    private let backTranslationUseCase: BackTranslationUseCase
    
    public init(
        fileRepository: FileRepository,
        batchRepository: BatchRepository,
        backTranslationUseCase: BackTranslationUseCase
    ) {
        self.fileRepository = fileRepository
        self.batchRepository = batchRepository
        self.backTranslationUseCase = backTranslationUseCase
    }
    
    /// Execute batch processing operation
    public func execute(
        fileURLs: [URL],
        sourceLanguage: Language,
        targetLanguage: Language,
        apiProvider: APIProvider
    ) async throws -> AsyncThrowingStream<BatchProgress, Error> {
        // Load and validate files
        let files = try await loadValidatedFiles(from: fileURLs)
        
        // Create batch operation
        let operation = BatchOperation(
            files: files,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            apiProvider: apiProvider
        )
        
        // Start batch processing
        return try await batchRepository.startBatchOperation(operation)
    }
    
    private func loadValidatedFiles(from urls: [URL]) async throws -> [TranslatableFile] {
        var files: [TranslatableFile] = []
        
        for url in urls {
            do {
                let isValid = try await fileRepository.validateFile(at: url)
                if isValid {
                    let file = try await fileRepository.loadFile(from: url)
                    files.append(file)
                }
            } catch {
                // Log error but continue with other files
                print("Failed to load file \(url.lastPathComponent): \(error)")
            }
        }
        
        return files
    }
}

/// Use case for cost management
public final class CostManagementUseCase {
    private let costTrackingRepository: CostTrackingRepository
    
    public init(costTrackingRepository: CostTrackingRepository) {
        self.costTrackingRepository = costTrackingRepository
    }
    
    /// Get comprehensive cost analysis
    public func getCostAnalysis() async throws -> CostAnalysis {
        let budgetStatus = try await costTrackingRepository.getBudgetStatus()
        let thirtyDayReport = try await costTrackingRepository.getCostReport(
            startDate: Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date(),
            endDate: Date()
        )
        let sevenDayReport = try await costTrackingRepository.getCostReport(
            startDate: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date(),
            endDate: Date()
        )
        
        return CostAnalysis(
            budgetStatus: budgetStatus,
            thirtyDayReport: thirtyDayReport,
            sevenDayReport: sevenDayReport
        )
    }
    
    /// Update budget settings
    public func updateBudget(
        monthlyLimitUSD: Double,
        alertThresholdPercent: Double
    ) async throws -> BudgetStatus {
        let budget = Budget(
            monthlyLimitUSD: monthlyLimitUSD,
            alertThresholdPercent: alertThresholdPercent
        )
        
        try await costTrackingRepository.updateBudget(budget)
        return try await costTrackingRepository.getBudgetStatus()
    }
}

/// Use case for EPUB processing
public final class EPUBProcessingUseCase {
    private let epubRepository: EPUBRepository
    private let backTranslationUseCase: BackTranslationUseCase
    
    public init(
        epubRepository: EPUBRepository,
        backTranslationUseCase: BackTranslationUseCase
    ) {
        self.epubRepository = epubRepository
        self.backTranslationUseCase = backTranslationUseCase
    }
    
    /// Process EPUB file for translation
    public func processEPUB(
        from url: URL,
        selectedChapterIds: [String],
        sourceLanguage: Language,
        targetLanguage: Language,
        apiProvider: APIProvider
    ) async throws -> EPUBTranslationResult {
        let book = try await epubRepository.loadEPUB(from: url)
        let selectedChapters = book.chapters.filter { selectedChapterIds.contains($0.id) }
        
        var chapterResults: [ChapterTranslationResult] = []
        
        for chapter in selectedChapters {
            let text = try await epubRepository.extractChapterText(chapter)
            let translationResult = try await backTranslationUseCase.execute(
                text: text,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                apiProvider: apiProvider
            )
            
            let chapterResult = ChapterTranslationResult(
                chapter: chapter,
                translationResult: translationResult
            )
            chapterResults.append(chapterResult)
        }
        
        return EPUBTranslationResult(
            book: book,
            chapterResults: chapterResults
        )
    }
}

/// Use case for exporting results
public final class ExportUseCase {
    private let exportRepository: ExportRepository
    
    public init(exportRepository: ExportRepository) {
        self.exportRepository = exportRepository
    }
    
    /// Export translation results
    public func export(
        results: [BackTranslationResult],
        format: ExportFormat,
        to url: URL,
        includeMetadata: Bool = true,
        includeQualityMetrics: Bool = true
    ) async throws {
        let config = ExportConfig(
            format: format,
            includeMetadata: includeMetadata,
            includeQualityMetrics: includeQualityMetrics
        )
        
        try await exportRepository.exportResults(results, config: config, to: url)
    }
    
    /// Generate export preview
    public func generatePreview(
        results: [BackTranslationResult],
        format: ExportFormat
    ) async throws -> String {
        return try await exportRepository.generatePreview(results, format: format)
    }
}

// MARK: - Supporting Types

/// Comprehensive cost analysis
public struct CostAnalysis: Equatable, Codable {
    public let budgetStatus: BudgetStatus
    public let thirtyDayReport: CostReport
    public let sevenDayReport: CostReport
    
    public var trendIndicator: CostTrend {
        let weeklyAverage = sevenDayReport.totalCostUSD / 7.0
        let monthlyProjection = weeklyAverage * 30.0
        
        if monthlyProjection > budgetStatus.monthlyLimitUSD {
            return .increasing
        } else if monthlyProjection < budgetStatus.monthlyLimitUSD * 0.5 {
            return .decreasing
        } else {
            return .stable
        }
    }
}

public enum CostTrend {
    case increasing
    case stable
    case decreasing
}

/// EPUB translation result
public struct EPUBTranslationResult: Equatable, Codable {
    public let book: EPUBBook
    public let chapterResults: [ChapterTranslationResult]
    
    public var totalCost: Double {
        return chapterResults.map { $0.translationResult.totalCost.costInUSD }.reduce(0, +)
    }
    
    public var averageQualityScore: Double {
        let scores = chapterResults.compactMap { $0.translationResult.qualityAssessment.bleuScore }
        guard !scores.isEmpty else { return 0.0 }
        return scores.reduce(0, +) / Double(scores.count)
    }
}

/// Chapter translation result
public struct ChapterTranslationResult: Equatable, Codable {
    public let chapter: EPUBChapter
    public let translationResult: BackTranslationResult
}

/// Translation errors
public enum TranslationError: LocalizedError {
    case invalidAPIKey(APIProvider)
    case networkError(String)
    case quotaExceeded
    case invalidInput(String)
    case notImplemented(String)
    case fileNotSupported(String)
    case budgetExceeded(Double)
    
    public var errorDescription: String? {
        switch self {
        case .invalidAPIKey(let provider):
            return "Invalid API key for \(provider.displayName)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .quotaExceeded:
            return "API quota exceeded"
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .notImplemented(let feature):
            return "Feature not implemented: \(feature)"
        case .fileNotSupported(let type):
            return "File type not supported: \(type)"
        case .budgetExceeded(let amount):
            return "Budget exceeded by $\(String(format: "%.2f", amount))"
        }
    }
}