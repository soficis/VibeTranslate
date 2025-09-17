import Foundation
import SwiftUI

public final class AppContainer: ObservableObject {
    @Published public var isInitialized = false
    
    // Core Services
    public private(set) var networkService: NetworkService!
    public private(set) var secureStorageService: SecureStorageService!
    public private(set) var translationMemoryService: TranslationMemoryService!
    public private(set) var costTrackingService: CostTrackingService!
    public private(set) var fileProcessingService: FileProcessingService!
    public private(set) var batchProcessingService: BatchProcessingService!
    public private(set) var translationService: TranslationService!
    public private(set) var epubProcessor: EpubProcessor!
    
    // Use Cases
    public private(set) var backTranslationUseCase: BackTranslationUseCase!
    public private(set) var batchProcessingUseCase: BatchProcessingUseCase!
    public private(set) var costManagementUseCase: CostManagementUseCase!
    public private(set) var exportUseCase: ExportUseCase!
    
    // Repositories
    public var translationMemoryRepository: TranslationMemoryRepository { 
        return translationMemoryService ?? TranslationMemoryService(config: TranslationMemoryConfig())
    }
    public var secureStorageRepository: SecureStorageRepository { 
        return secureStorageService ?? SecureStorageService()
    }
    
    public init() {
        print("🚀 AppContainer: Starting initialization...")
        
        // Start async initialization immediately but don't block the UI thread
        Task { @MainActor in
            await self.initializeServices()
        }
    }
    
    @MainActor
    private func initializeServices() async {
        print("🔧 AppContainer: Initializing services asynchronously...")
        let start = Date()
        
    // Initialize core services first
    print("▶️ Initializing core services")
    self.networkService = NetworkService()
    self.secureStorageService = SecureStorageService()
    self.epubProcessor = EpubProcessor()

    print("✅ AppContainer: Basic services ready (" + String(format: "%.3f", Date().timeIntervalSince(start)) + "s)")
        
        // Allow UI to update
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        // Initialize more complex services
        let tmConfig = TranslationMemoryConfig(maxCacheSize: 10000, similarityThreshold: 0.8)
        self.translationMemoryService = TranslationMemoryService(config: tmConfig)
        
        self.costTrackingService = CostTrackingService()
        self.fileProcessingService = FileProcessingService()
        
        self.translationService = TranslationService(
            networkService: networkService,
            secureStorage: secureStorageService
        )
        
    print("✅ AppContainer: Translation services ready (" + String(format: "%.3f", Date().timeIntervalSince(start)) + "s)")
        
        // Create quality service
        let qualityService = QualityService()
        
        // Initialize use cases
        self.backTranslationUseCase = BackTranslationUseCase(
            translationRepository: translationService,
            costTrackingRepository: costTrackingService,
            translationMemoryRepository: translationMemoryService,
            qualityRepository: qualityService
        )
        
        self.batchProcessingService = BatchProcessingService(
            fileRepository: fileProcessingService,
            backTranslationUseCase: backTranslationUseCase
        )
        
        self.batchProcessingUseCase = BatchProcessingUseCase(
            fileRepository: fileProcessingService,
            batchRepository: batchProcessingService,
            backTranslationUseCase: backTranslationUseCase
        )
        
        self.costManagementUseCase = CostManagementUseCase(
            costTrackingRepository: costTrackingService
        )
        
        self.exportUseCase = ExportUseCase(
            exportRepository: ExportService()
        )
        
        print("🎉 AppContainer: All services initialized successfully! (" + String(format: "%.3f", Date().timeIntervalSince(start)) + "s)")
        self.isInitialized = true
    }
}

// Basic QualityService implementation
public final class QualityService: QualityRepository {
    public func calculateBLEUScore(
        reference: String,
        candidate: String
    ) async throws -> Double {
        return 0.75 // Simplified implementation
    }
    
    public func assessQuality(originalText: String, backTranslatedText: String) async throws -> QualityAssessment {
        return QualityAssessment(
            bleuScore: 0.75,
            recommendations: ["Consider reviewing translation accuracy"]
        )
    }
    
    public func getQualityRecommendations(
        bleuScore: Double,
        originalLength: Int,
        translatedLength: Int
    ) async throws -> [String] {
        return ["Consider reviewing translation accuracy", "Length ratio: \(translatedLength)/\(originalLength)"]
    }
}

// Basic ExportService implementation
public final class ExportService: ExportRepository {
    public func exportResults(
        _ results: [BackTranslationResult],
        config: ExportConfig,
        to url: URL
    ) async throws {
        let content = "Export Report\nResults: \(results.count)"
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
    
    public func generatePreview(
        _ results: [BackTranslationResult],
        format: ExportFormat
    ) async throws -> String {
        return "Preview: \(results.count) results"
    }
    
    public func getAvailableTemplates(for format: ExportFormat) async throws -> [String] {
        return ["Standard", "Detailed"]
    }
}
