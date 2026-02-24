import Foundation

/// Repository protocol for translation services.
public protocol TranslationRepository {
    /// Translate text from source to target language.
    func translate(
        text: String,
        sourceLanguage: Language,
        targetLanguage: Language,
        apiProvider: APIProvider
    ) async throws -> TranslationResult

    /// Perform back-translation (source -> target -> source).
    func backTranslate(
        text: String,
        sourceLanguage: Language,
        targetLanguage: Language,
        apiProvider: APIProvider
    ) async throws -> BackTranslationResult
}

/// Repository protocol for translation memory.
public protocol TranslationMemoryRepository {
    /// Look up exact translation match.
    func lookupExact(
        sourceText: String,
        sourceLanguage: Language,
        targetLanguage: Language
    ) async throws -> TranslationMemoryEntry?

    /// Store translation in memory.
    func store(_ entry: TranslationMemoryEntry) async throws

    /// Get translation memory statistics.
    func getStats() async throws -> TranslationMemoryStats

    /// Clear translation memory.
    func clearMemory() async throws

    /// Persist memory to storage.
    func persist() async throws
}

/// Repository protocol for file operations.
public protocol FileRepository {
    /// Load translatable file from URL.
    func loadFile(from url: URL) async throws -> TranslatableFile

    /// Save translation result to file.
    func saveTranslation(_ result: BackTranslationResult, to url: URL) async throws

    /// Get supported file types.
    func getSupportedFileTypes() -> [SupportedFileType]

    /// Validate file for translation.
    func validateFile(at url: URL) async throws -> Bool
}

/// Repository protocol for batch processing.
public protocol BatchRepository {
    /// Start batch processing operation.
    func startBatchOperation(_ operation: BatchOperation) async throws -> AsyncThrowingStream<BatchProgress, Error>

    /// Cancel batch operation.
    func cancelBatchOperation(id: UUID) async throws

    /// Get batch operation status.
    func getBatchOperationStatus(id: UUID) async throws -> BatchOperation?

    /// Get all batch operations.
    func getAllBatchOperations() async throws -> [BatchOperation]
}

/// Repository protocol for EPUB processing.
public protocol EPUBRepository {
    /// Load EPUB book from file.
    func loadEPUB(from url: URL) async throws -> EPUBBook

    /// Extract text from EPUB chapter.
    func extractChapterText(_ chapter: EPUBChapter) async throws -> String

    /// Get EPUB metadata.
    func getEPUBMetadata(from url: URL) async throws -> [String: String]
}

/// Repository protocol for export functionality.
public protocol ExportRepository {
    /// Export translation results to specified format.
    func exportResults(
        _ results: [BackTranslationResult],
        config: ExportConfig,
        to url: URL
    ) async throws

    /// Generate export preview.
    func generatePreview(
        _ results: [BackTranslationResult],
        format: ExportFormat
    ) async throws -> String

    /// Get available export templates.
    func getAvailableTemplates(for format: ExportFormat) async throws -> [String]
}
