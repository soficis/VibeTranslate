import Foundation
import SwiftUI
import Combine

/// Main view model for the translation interface
/// Following Clean Code: meaningful names and clear responsibilities
@MainActor
public final class MainViewModel: ObservableObject {
    private var appContainer: AppContainer?
    
    public init() {}
    
    public func configure(with container: AppContainer) {
        self.appContainer = container
    }
}

/// View model for translation functionality
@MainActor
public final class TranslationViewModel: ObservableObject {
    @Published var inputText = ""
    @Published var selectedAPIProvider = APIProvider.googleUnofficialAPI
    @Published var translationResult: BackTranslationResult?
    @Published var isTranslating = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var showFileImporter = false
    @Published var showEpubImporter = false
    @Published var extractedEpubText: String = ""
    
    private var appContainer: AppContainer?
    private var backTranslationUseCase: BackTranslationUseCase?
    
    public func configure(with container: AppContainer) {
        self.appContainer = container
        // Only set up use case if container is already initialized
        // Otherwise it will be set up when container finishes initializing
        if container.isInitialized {
            self.backTranslationUseCase = container.backTranslationUseCase
        }
    }
    
    public func performBackTranslation() async {
        guard let container = appContainer else { return }
        if !container.isInitialized { await container.initialize() }

        guard !inputText.isEmpty else {
            showErrorMessage("Please enter text to translate")
            return
        }

        isTranslating = true
        translationResult = nil
        defer { isTranslating = false }
        
        do {
            let result = try await container.backTranslationUseCase.execute(
                text: inputText,
                sourceLanguage: .english,
                targetLanguage: .japanese,
                apiProvider: selectedAPIProvider
            )
            
            translationResult = result
        } catch {
            handleError(error)
        }
    }
    
    public func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            // Perform file I/O off the main actor to avoid blocking the UI
            Task.detached { [url] in
                do {
                    let content = try String(contentsOf: url, encoding: .utf8)
                    await MainActor.run {
                        self.inputText = content
                    }
                } catch {
                    await MainActor.run {
                        self.showErrorMessage("Failed to load file")
                    }
                }
            }
            
        case .failure(_):
            showErrorMessage("File selection failed")
        }
    }
    
    func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
    private func handleError(_ error: Error) {
        if let translationError = error as? TranslationError {
            showErrorMessage(translationError.errorDescription ?? translationError.localizedDescription)
        } else {
            showErrorMessage(error.localizedDescription)
        }
    }
}

/// View model for batch processing
@MainActor
public final class BatchProcessingViewModel: ObservableObject {
    @Published var selectedFiles: [URL] = []
    @Published var selectedAPIProvider = APIProvider.googleUnofficialAPI
    @Published var sourceLanguage = Language.english
    @Published var targetLanguage = Language.japanese
    @Published var isProcessing = false
    @Published var progress: BatchProgress?
    @Published var results: [BatchTranslationResult] = []
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var showFileImporter = false
    @Published var showEpubImporter = false
    @Published var extractedEpubText = ""
    
    private var appContainer: AppContainer?
    private var batchProcessingUseCase: BatchProcessingUseCase?
    private var currentTask: Task<Void, Never>?
    private var epubProcessor: EpubProcessor? { appContainer?.epubProcessor }
    
    public func configure(with container: AppContainer) {
        self.appContainer = container
        self.batchProcessingUseCase = container.batchProcessingUseCase
    }
    
    public func startBatchProcessing() async {
        guard !selectedFiles.isEmpty,
              let useCase = batchProcessingUseCase else {
            showErrorMessage("Please select files to process")
            return
        }
        // Kick off processing on a background task so we don't block the main actor
        await MainActor.run {
            self.isProcessing = true
            self.progress = BatchProgress(totalFiles: selectedFiles.count)
            self.results = []
        }

        currentTask = Task.detached { [selectedFiles, sourceLanguage, targetLanguage, selectedAPIProvider, useCase] in
            do {
                let progressStream = try await useCase.execute(
                    fileURLs: selectedFiles,
                    sourceLanguage: sourceLanguage,
                    targetLanguage: targetLanguage,
                    apiProvider: selectedAPIProvider
                )

                for try await batchProgress in progressStream {
                    await MainActor.run {
                        self.progress = batchProgress
                    }
                }

                await MainActor.run {
                    self.isProcessing = false
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                }
                await MainActor.run {
                    self.isProcessing = false
                    self.handleError(error)
                }
            }
        }
    }
    
    public func cancelBatchProcessing() {
        currentTask?.cancel()
        currentTask = nil
        isProcessing = false
    }
    
    public func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            selectedFiles = urls
            
        case .failure(_):
            showErrorMessage("File selection failed")
        }
    }

    public func extractTextFromEpub(_ url: URL) async throws -> String {
        guard let processor = epubProcessor else { throw NSError(domain: "BatchVM", code: 1, userInfo: [NSLocalizedDescriptionKey: "EPUB processor unavailable"]) }
        return try await processor.extractText(from: url)
    }
    
    func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }

    private func handleError(_ error: Error) {
        if let translationError = error as? TranslationError {
            showErrorMessage(translationError.errorDescription ?? translationError.localizedDescription)
        } else {
            showErrorMessage(error.localizedDescription)
        }
    }
}

/// View model for cost tracking
@MainActor
public final class CostTrackingViewModel: ObservableObject {
    @Published var budgetStatus: BudgetStatus?
    @Published var costAnalysis: CostAnalysis?
    @Published var monthlyBudgetLimit: Double = 50.0
    @Published var alertThreshold: Double = 80.0
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var isLoading = false
    
    private var appContainer: AppContainer?
    private var costManagementUseCase: CostManagementUseCase?
    
    public func configure(with container: AppContainer) {
        self.appContainer = container
        self.costManagementUseCase = container.costManagementUseCase
    }
    
    public func loadCostData() async {
        guard let useCase = costManagementUseCase else { return }
        
        isLoading = true
        
        do {
            let analysis = try await useCase.getCostAnalysis()
            costAnalysis = analysis
            budgetStatus = analysis.budgetStatus
            monthlyBudgetLimit = analysis.budgetStatus.monthlyLimitUSD
            alertThreshold = analysis.budgetStatus.alertThresholdPercent
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
    
    public func updateBudget() async {
        guard let useCase = costManagementUseCase else { return }
        
        do {
            let newStatus = try await useCase.updateBudget(
                monthlyLimitUSD: monthlyBudgetLimit,
                alertThresholdPercent: alertThreshold
            )
            budgetStatus = newStatus
        } catch {
            handleError(error)
        }
    }
    
    func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }

    private func handleError(_ error: Error) {
        if let translationError = error as? TranslationError {
            showErrorMessage(translationError.errorDescription ?? translationError.localizedDescription)
        } else {
            showErrorMessage(error.localizedDescription)
        }
    }
}

/// View model for translation memory
@MainActor
public final class TranslationMemoryViewModel: ObservableObject {
    @Published var stats: TranslationMemoryStats?
    @Published var searchText = ""
    @Published var searchResults: [FuzzyMatch] = []
    @Published var isSearching = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    private var appContainer: AppContainer?
    
    public func configure(with container: AppContainer) {
        self.appContainer = container
    }
    
    public func loadStats() async {
        guard let container = appContainer else { return }
        
        // Ensure initialization is complete without blocking loops
        if !container.isInitialized {
            await container.initialize()
        }
        
        do {
            stats = try await container.translationMemoryRepository.getStats()
        } catch {
            showErrorMessage(error.localizedDescription)
        }
    }
    
    public func searchMemory() async {
        guard let container = appContainer else { return }
        if !container.isInitialized { await container.initialize() }
        
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        defer { isSearching = false }
        
        do {
            let matches = try await container.translationMemoryRepository.lookupFuzzy(
                sourceText: searchText,
                sourceLanguage: .english,
                targetLanguage: .japanese,
                threshold: 0.5
            )
            searchResults = matches
        } catch {
            showErrorMessage(error.localizedDescription)
        }
    }
    
    public func clearMemory() async {
        guard let container = appContainer else { return }
        if !container.isInitialized { await container.initialize() }
        
        do {
            try await container.translationMemoryRepository.clearMemory()
            await loadStats()
            searchResults = []
        } catch {
            showErrorMessage(error.localizedDescription)
        }
    }
    
    func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
}

/// View model for export functionality
@MainActor
public final class ExportViewModel: ObservableObject {
    @Published var availableResults: [BackTranslationResult] = []
    @Published var selectedResults: Set<BackTranslationResult.ID> = []
    @Published var selectedFormat = ExportFormat.pdf
    @Published var includeMetadata = true
    @Published var includeQualityMetrics = true
    @Published var isExporting = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var showFileSaver = false
    @Published var exportPreview = ""
    
    private var appContainer: AppContainer?
    private var exportUseCase: ExportUseCase?
    
    public func configure(with container: AppContainer) {
        self.appContainer = container
        self.exportUseCase = container.exportUseCase
    }
    
    public func generatePreview() async {
        guard let useCase = exportUseCase else { return }
        
        let resultsToExport = availableResults.filter { selectedResults.contains($0.id) }
        guard !resultsToExport.isEmpty else {
            showErrorMessage("Please select results to export")
            return
        }
        
        do {
            exportPreview = try await useCase.generatePreview(
                results: resultsToExport,
                format: selectedFormat
            )
        } catch {
            handleError(error)
        }
    }
    
    public func exportResults(to url: URL) async {
        guard let useCase = exportUseCase else { return }
        
        let resultsToExport = availableResults.filter { selectedResults.contains($0.id) }
        guard !resultsToExport.isEmpty else {
            showErrorMessage("Please select results to export")
            return
        }
        
        isExporting = true
        
        do {
            try await useCase.export(
                results: resultsToExport,
                format: selectedFormat,
                to: url,
                includeMetadata: includeMetadata,
                includeQualityMetrics: includeQualityMetrics
            )
        } catch {
            handleError(error)
        }
        
        isExporting = false
    }
    
    func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }

    private func handleError(_ error: Error) {
        if let translationError = error as? TranslationError {
            showErrorMessage(translationError.errorDescription ?? translationError.localizedDescription)
        } else {
            showErrorMessage(error.localizedDescription)
        }
    }
}
