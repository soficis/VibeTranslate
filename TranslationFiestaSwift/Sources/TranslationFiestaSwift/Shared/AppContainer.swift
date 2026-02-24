import Foundation
import SwiftUI
import Logging

public final class AppContainer: ObservableObject {
    @Published public private(set) var isInitialized = false

    private let logger = Logger(label: "AppContainer")

    // MARK: - Services
    private var _translationMemoryService: TranslationMemoryService?
    private var _fileProcessingService: FileProcessingService?
    private var _batchProcessingService: BatchProcessingService?
    private var _translationService: TranslationService?
    private var _epubProcessor: EpubProcessor?

    // MARK: - Use Cases
    private var _backTranslationUseCase: BackTranslationUseCase?
    private var _batchProcessingUseCase: BatchProcessingUseCase?
    private var _exportUseCase: ExportUseCase?

    // Public Accessors
    public var translationMemoryService: TranslationMemoryService { _translationMemoryService! }
    public var fileProcessingService: FileProcessingService { _fileProcessingService! }
    public var batchProcessingService: BatchProcessingService { _batchProcessingService! }
    public var translationService: TranslationService { _translationService! }
    public var epubProcessor: EpubProcessor { _epubProcessor! }

    public var backTranslationUseCase: BackTranslationUseCase { _backTranslationUseCase! }
    public var batchProcessingUseCase: BatchProcessingUseCase { _batchProcessingUseCase! }
    public var exportUseCase: ExportUseCase { _exportUseCase! }

    // Repository Accessors (for ViewModel access)
    public var translationMemoryRepository: TranslationMemoryService { _translationMemoryService! }

    public init() {
        logger.info("AppContainer initialized")
    }

    @MainActor
    public func initialize() async {
        guard !isInitialized else { return }

        logger.info("Starting service initialization...")

        _epubProcessor = EpubProcessor()

        let tmConfig = TranslationMemoryConfig(maxCacheSize: 10_000, similarityThreshold: 0.8)
        let tmService = TranslationMemoryService(config: tmConfig)
        _translationMemoryService = tmService

        let fileProcessing = FileProcessingService()
        _fileProcessingService = fileProcessing

        let translation = TranslationService()
        _translationService = translation

        let qualityService = QualityService()

        let backTranslation = BackTranslationUseCase(
            translationRepository: translation,
            translationMemoryRepository: tmService,
            qualityRepository: qualityService
        )
        _backTranslationUseCase = backTranslation

        let batchProcessing = BatchProcessingService(
            fileRepository: fileProcessing,
            backTranslationUseCase: backTranslation
        )
        _batchProcessingService = batchProcessing

        _batchProcessingUseCase = BatchProcessingUseCase(
            fileRepository: fileProcessing,
            batchRepository: batchProcessing,
            backTranslationUseCase: backTranslation
        )

        _exportUseCase = ExportUseCase(exportRepository: ExportService())

        isInitialized = true
        logger.info("Service initialization completed successfully")
    }
}

public final class QualityService: QualityRepository {
    public func calculateBLEUScore(reference: String, candidate: String) async throws -> Double {
        0.75
    }

    public func assessQuality(originalText: String, backTranslatedText: String) async throws -> QualityAssessment {
        QualityAssessment(bleuScore: 0.75, recommendations: ["Consider reviewing translation accuracy"])
    }

    public func getQualityRecommendations(
        bleuScore: Double,
        originalLength: Int,
        translatedLength: Int
    ) async throws -> [String] {
        ["Consider reviewing translation accuracy", "Length ratio: \(translatedLength)/\(originalLength)"]
    }
}

public final class ExportService: ExportRepository {
    public func exportResults(_ results: [BackTranslationResult], config: ExportConfig, to url: URL) async throws {
        let content = "Export Report\nResults: \(results.count)"
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    public func generatePreview(_ results: [BackTranslationResult], format: ExportFormat) async throws -> String {
        "Preview: \(results.count) results"
    }

    public func getAvailableTemplates(for format: ExportFormat) async throws -> [String] {
        ["Standard", "Detailed"]
    }
}
