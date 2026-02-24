import Foundation

/// Use case for performing back-translations.
public final class BackTranslationUseCase {
    private let translationRepository: TranslationRepository
    private let translationMemoryRepository: TranslationMemoryRepository

    public init(
        translationRepository: TranslationRepository,
        translationMemoryRepository: TranslationMemoryRepository
    ) {
        self.translationRepository = translationRepository
        self.translationMemoryRepository = translationMemoryRepository
    }

    /// Execute back-translation with translation memory.
    public func execute(
        text: String,
        sourceLanguage: Language,
        targetLanguage: Language,
        apiProvider: APIProvider
    ) async throws -> BackTranslationResult {
        if let cachedResult = try await checkTranslationMemory(
            text: text,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        ) {
            return cachedResult
        }

        let result = try await translationRepository.backTranslate(
            text: text,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            apiProvider: apiProvider
        )

        try await storeInTranslationMemory(result: result)
        return result
    }

    private func checkTranslationMemory(
        text: String,
        sourceLanguage: Language,
        targetLanguage: Language
    ) async throws -> BackTranslationResult? {
        if let exactMatch = try await translationMemoryRepository.lookupExact(
            sourceText: text,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        ) {
            return try await createResultFromMemoryEntry(exactMatch)
        }

        return nil
    }

    private func createResultFromMemoryEntry(_ entry: TranslationMemoryEntry) async throws -> BackTranslationResult {
        let forwardResult = TranslationResult(
            originalText: entry.sourceText,
            translatedText: entry.translatedText,
            sourceLanguage: entry.sourceLanguage,
            targetLanguage: entry.targetLanguage,
            apiProvider: .googleUnofficialAPI
        )

        let backwardEntry = try await translationMemoryRepository.lookupExact(
            sourceText: entry.translatedText,
            sourceLanguage: entry.targetLanguage,
            targetLanguage: entry.sourceLanguage
        )

        let backwardResult: TranslationResult
        if let bEntry = backwardEntry {
            backwardResult = TranslationResult(
                originalText: bEntry.sourceText,
                translatedText: bEntry.translatedText,
                sourceLanguage: bEntry.sourceLanguage,
                targetLanguage: bEntry.targetLanguage,
                apiProvider: .googleUnofficialAPI
            )
        } else {
            backwardResult = TranslationResult(
                originalText: entry.translatedText,
                translatedText: entry.sourceText,
                sourceLanguage: entry.targetLanguage,
                targetLanguage: entry.sourceLanguage,
                apiProvider: .googleUnofficialAPI
            )
        }

        return BackTranslationResult(
            originalEnglish: entry.sourceLanguage == .english ? entry.sourceText : backwardResult.translatedText,
            japanese: entry.targetLanguage == .japanese ? entry.translatedText : entry.sourceText,
            backTranslatedEnglish: entry.sourceLanguage == .english ? backwardResult.translatedText : entry.sourceText,
            forwardTranslation: forwardResult,
            backwardTranslation: backwardResult
        )
    }

    private func storeInTranslationMemory(result: BackTranslationResult) async throws {
        let forwardEntry = TranslationMemoryEntry(
            sourceText: result.forwardTranslation.originalText,
            translatedText: result.forwardTranslation.translatedText,
            sourceLanguage: result.forwardTranslation.sourceLanguage,
            targetLanguage: result.forwardTranslation.targetLanguage
        )
        try await translationMemoryRepository.store(forwardEntry)

        let backwardEntry = TranslationMemoryEntry(
            sourceText: result.backwardTranslation.originalText,
            translatedText: result.backwardTranslation.translatedText,
            sourceLanguage: result.backwardTranslation.sourceLanguage,
            targetLanguage: result.backwardTranslation.targetLanguage
        )
        try await translationMemoryRepository.store(backwardEntry)
    }
}

/// Use case for batch processing files.
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

    /// Execute batch processing operation.
    public func execute(
        fileURLs: [URL],
        sourceLanguage: Language,
        targetLanguage: Language,
        apiProvider: APIProvider
    ) async throws -> AsyncThrowingStream<BatchProgress, Error> {
        let files = try await loadValidatedFiles(from: fileURLs)

        let operation = BatchOperation(
            files: files,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            apiProvider: apiProvider
        )

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
                print("Failed to load file \(url.lastPathComponent): \(error)")
            }
        }

        return files
    }
}

/// Use case for EPUB processing.
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

    /// Process EPUB file for translation.
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

/// Use case for exporting results.
public final class ExportUseCase {
    private let exportRepository: ExportRepository

    public init(exportRepository: ExportRepository) {
        self.exportRepository = exportRepository
    }

    /// Export translation results.
    public func export(
        results: [BackTranslationResult],
        format: ExportFormat,
        to url: URL,
        includeMetadata: Bool = true
    ) async throws {
        let config = ExportConfig(
            format: format,
            includeMetadata: includeMetadata
        )

        try await exportRepository.exportResults(results, config: config, to: url)
    }

    /// Generate export preview.
    public func generatePreview(
        results: [BackTranslationResult],
        format: ExportFormat
    ) async throws -> String {
        try await exportRepository.generatePreview(results, format: format)
    }
}

// MARK: - Supporting Types

/// EPUB translation result.
public struct EPUBTranslationResult: Equatable, Codable {
    public let book: EPUBBook
    public let chapterResults: [ChapterTranslationResult]
}

/// Chapter translation result.
public struct ChapterTranslationResult: Equatable, Codable {
    public let chapter: EPUBChapter
    public let translationResult: BackTranslationResult
}

/// Translation errors.
public enum TranslationError: LocalizedError {
    case networkError(String)
    case rateLimited
    case blocked
    case invalidResponse(String)
    case invalidInput(String)
    case notImplemented(String)
    case fileNotSupported(String)

    public var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network error: \(message)"
        case .rateLimited:
            return "Provider rate limited"
        case .blocked:
            return "Provider blocked or captcha detected"
        case .invalidResponse(let message):
            return "Invalid response: \(message)"
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .notImplemented(let feature):
            return "Feature not implemented: \(feature)"
        case .fileNotSupported(let type):
            return "File type not supported: \(type)"
        }
    }
}
