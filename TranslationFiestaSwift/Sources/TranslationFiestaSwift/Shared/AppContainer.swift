import Foundation
import SwiftUI

public final class AppContainer: ObservableObject {
    @Published public private(set) var isInitialized = false
    @Published public private(set) var costTrackingEnabled: Bool

    private static let costTrackingEnabledKey = "cost_tracking_enabled"

    public private(set) var networkService: NetworkService!
    public private(set) var secureStorageService: SecureStorageService!
    public private(set) var translationMemoryService: TranslationMemoryService!
    public private(set) var costTrackingService: CostTrackingService!
    public private(set) var fileProcessingService: FileProcessingService!
    public private(set) var batchProcessingService: BatchProcessingService!
    public private(set) var translationService: TranslationService!
    public private(set) var epubProcessor: EpubProcessor!

    public private(set) var backTranslationUseCase: BackTranslationUseCase!
    public private(set) var batchProcessingUseCase: BatchProcessingUseCase!
    public private(set) var costManagementUseCase: CostManagementUseCase!
    public private(set) var exportUseCase: ExportUseCase!

    public init() {
        let enabled = UserDefaults.standard.bool(forKey: Self.costTrackingEnabledKey)
        self.costTrackingEnabled = enabled
        Self.applyCostTrackingEnvironment(enabled)

        Task { @MainActor in
            await initializeServices()
        }
    }

    public func setCostTrackingEnabled(_ enabled: Bool) {
        costTrackingEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.costTrackingEnabledKey)
        Self.applyCostTrackingEnvironment(enabled)
    }

    private static func applyCostTrackingEnvironment(_ enabled: Bool) {
        setenv("TF_COST_TRACKING_ENABLED", enabled ? "1" : "0", 1)
    }

    @MainActor
    private func initializeServices() async {
        networkService = NetworkService()
        secureStorageService = SecureStorageService()
        epubProcessor = EpubProcessor()

        let tmConfig = TranslationMemoryConfig(maxCacheSize: 10_000, similarityThreshold: 0.8)
        translationMemoryService = TranslationMemoryService(config: tmConfig)

        costTrackingService = CostTrackingService()
        fileProcessingService = FileProcessingService()

        translationService = TranslationService(
            networkService: networkService,
            secureStorage: secureStorageService
        )

        let qualityService = QualityService()

        backTranslationUseCase = BackTranslationUseCase(
            translationRepository: translationService,
            costTrackingRepository: costTrackingService,
            translationMemoryRepository: translationMemoryService,
            qualityRepository: qualityService
        )

        batchProcessingService = BatchProcessingService(
            fileRepository: fileProcessingService,
            backTranslationUseCase: backTranslationUseCase
        )

        batchProcessingUseCase = BatchProcessingUseCase(
            fileRepository: fileProcessingService,
            batchRepository: batchProcessingService,
            backTranslationUseCase: backTranslationUseCase
        )

        costManagementUseCase = CostManagementUseCase(costTrackingRepository: costTrackingService)
        exportUseCase = ExportUseCase(exportRepository: ExportService())

        isInitialized = true
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
