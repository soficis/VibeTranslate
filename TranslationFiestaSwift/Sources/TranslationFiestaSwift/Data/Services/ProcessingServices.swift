import Foundation
import Logging

/// Cost tracking service with budget management
/// Following Clean Code: clear intent and single responsibility
public final class CostTrackingService: CostTrackingRepository {
    private let logger = Logger(label: "CostTrackingService")
    private let fileManager: FileManager
    private let persistencePath: String
    
    private var budget: Budget
    private var costEntries: [CostEntry]
    private let persistenceQueue = DispatchQueue(label: "cost-tracking-persistence", qos: .utility)
    
    public init(
        persistencePath: String = "translation_costs.json",
        fileManager: FileManager = .default
    ) {
        self.persistencePath = persistencePath
        self.fileManager = fileManager
        self.budget = Budget()
        self.costEntries = []
        
        guard Self.isEnabled() else {
            return
        }

        Task.detached(priority: .background) { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 100_000_000)
                try await self?.loadFromPersistence()
            } catch {
                self?.logger.debug("Cost tracking initialization failed: \(error.localizedDescription)")
            }
        }
    }
    
    public func trackCost(_ entry: CostEntry) async throws {
        guard Self.isEnabled() else { return }

        costEntries.append(entry)
        budget.addUsage(entry.costUSD)
        
        logger.info("Cost tracked", metadata: [
            "amount": "\(entry.costUSD)",
            "characters": "\(entry.characterCount)",
            "provider": "\(entry.apiProvider.rawValue)",
            "monthlyUsage": "\(budget.currentMonthUsageUSD)"
        ])
        
        // Check for budget alerts
        checkBudgetAlerts()
        
        // Persist changes
        try await persist()
    }
    
    public func getBudgetStatus() async throws -> BudgetStatus {
        budget.resetIfNewMonth()
        return BudgetStatus(from: budget)
    }
    
    public func updateBudget(_ newBudget: Budget) async throws {
        guard Self.isEnabled() else { return }

        budget = newBudget
        logger.info("Budget updated", metadata: [
            "monthlyLimit": "\(newBudget.monthlyLimitUSD)",
            "alertThreshold": "\(newBudget.alertThresholdPercent)"
        ])
        
        try await persist()
    }
    
    public func getCostReport(startDate: Date, endDate: Date) async throws -> CostReport {
        let filteredEntries = costEntries.filter { entry in
            entry.timestamp >= startDate && entry.timestamp <= endDate
        }
        
        return CostReport(entries: filteredEntries, startDate: startDate, endDate: endDate)
    }
    
    public func getAllCostEntries() async throws -> [CostEntry] {
        return costEntries.sorted { $0.timestamp > $1.timestamp }
    }
    
    public func clearCostData() async throws {
        guard Self.isEnabled() else { return }

        costEntries.removeAll()
        budget = Budget()
        
        logger.info("Cost data cleared")
        try await persist()
    }

    private static func isEnabled() -> Bool {
        ProcessInfo.processInfo.environment["TF_COST_TRACKING_ENABLED"] == "1"
    }
    
    // MARK: - Private Methods
    
    private func checkBudgetAlerts() {
        guard budget.alertsEnabled else { return }
        
        if budget.isOverBudget {
            let alert = BudgetAlert.budgetExceeded(
                amount: budget.currentMonthUsageUSD,
                overage: budget.currentMonthUsageUSD - budget.monthlyLimitUSD
            )
            postBudgetAlert(alert)
        } else if budget.shouldAlert {
            let alert = BudgetAlert.thresholdReached(
                percentage: budget.usagePercentage,
                amount: budget.currentMonthUsageUSD
            )
            postBudgetAlert(alert)
        }
    }
    
    private func postBudgetAlert(_ alert: BudgetAlert) {
        logger.warning("Budget alert", metadata: [
            "type": "\(alert.title)",
            "message": "\(alert.message)"
        ])
        
        // Post notification for UI to handle
        NotificationCenter.default.post(
            name: .budgetAlert,
            object: alert
        )
    }
    
    private func loadFromPersistence() async throws {
        let url = getPersistenceURL()
        
        guard fileManager.fileExists(atPath: url.path) else {
            logger.info("No existing cost tracking file found")
            return
        }
        
        let data = try Data(contentsOf: url)
        let container = try JSONDecoder().decode(CostTrackingContainer.self, from: data)
        
        self.budget = container.budget
        self.costEntries = container.entries
        
        // Reset budget if new month
        budget.resetIfNewMonth()
        
        logger.info("Cost tracking data loaded", metadata: [
            "entries": "\(costEntries.count)",
            "monthlyUsage": "\(budget.currentMonthUsageUSD)"
        ])
    }
    
    private func persist() async throws {
        // Capture current state to avoid Sendable issues
        let currentBudget = budget
        let currentEntries = costEntries
        let persistenceURL = getPersistenceURL()
        let logger = self.logger

        try await withCheckedThrowingContinuation { continuation in
            persistenceQueue.async {
                let fileManager = FileManager.default
                do {
                    let url = persistenceURL

                    // Create backup
                    let backupURL = url.appendingPathExtension("backup")
                    if fileManager.fileExists(atPath: url.path) {
                        _ = try? fileManager.replaceItem(at: backupURL, withItemAt: url, backupItemName: nil, options: [], resultingItemURL: nil)
                    }

                    let container = CostTrackingContainer(budget: currentBudget, entries: currentEntries)
                    let data = try JSONEncoder().encode(container)
                    try data.write(to: url)

                    logger.debug("Cost tracking data saved", metadata: [
                        "entries": "\(currentEntries.count)",
                        "size": "\(data.count) bytes"
                    ])

                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func saveToPersistence() throws {
        let url = getPersistenceURL()
        
        // Create backup
        let backupURL = url.appendingPathExtension("backup")
        if fileManager.fileExists(atPath: url.path) {
            _ = try? fileManager.replaceItem(at: backupURL, withItemAt: url, backupItemName: nil, options: [], resultingItemURL: nil)
        }
        
        let container = CostTrackingContainer(budget: budget, entries: costEntries)
        let data = try JSONEncoder().encode(container)
        try data.write(to: url)
        
        logger.debug("Cost tracking data saved", metadata: [
            "entries": "\(costEntries.count)",
            "size": "\(data.count) bytes"
        ])
    }
    
    private func getPersistenceURL() -> URL {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent(persistencePath)
    }
}

// MARK: - Supporting Types

private struct CostTrackingContainer: Codable {
    let budget: Budget
    let entries: [CostEntry]
}

// MARK: - Notifications

extension Notification.Name {
    static let budgetAlert = Notification.Name("budgetAlert")
}

/// File processing service for loading and validating files
public final class FileProcessingService: FileRepository {
    private let logger = Logger(label: "FileProcessingService")
    private let fileManager: FileManager
    
    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }
    
    public func loadFile(from url: URL) async throws -> TranslatableFile {
        guard fileManager.fileExists(atPath: url.path) else {
            throw TranslationError.fileNotSupported("File does not exist")
        }
        
        let pathExtension = url.pathExtension.lowercased()
        guard let fileType = SupportedFileType.fromFileExtension(pathExtension) else {
            throw TranslationError.fileNotSupported("Unsupported file type: \(pathExtension)")
        }
        
        let content: String
        
        switch fileType {
        case .text, .markdown:
            content = try String(contentsOf: url, encoding: .utf8)
            
        case .html:
            let htmlContent = try String(contentsOf: url, encoding: .utf8)
            content = try extractTextFromHTML(htmlContent)
            
        case .epub:
            throw TranslationError.notImplemented("EPUB processing")
        }
        
        logger.info("File loaded", metadata: [
            "path": "\(url.lastPathComponent)",
            "type": "\(fileType.rawValue)",
            "size": "\(content.count) characters"
        ])
        
        return try TranslatableFile(url: url, content: content, fileType: fileType)
    }
    
    public func saveTranslation(_ result: BackTranslationResult, to url: URL) async throws {
        let content = formatTranslationResult(result)
        try content.write(to: url, atomically: true, encoding: .utf8)
        
        logger.info("Translation saved", metadata: [
            "path": "\(url.lastPathComponent)",
            "size": "\(content.count) characters"
        ])
    }
    
    public func getSupportedFileTypes() -> [SupportedFileType] {
        return SupportedFileType.allCases
    }
    
    public func validateFile(at url: URL) async throws -> Bool {
        guard fileManager.fileExists(atPath: url.path) else {
            return false
        }
        
        let pathExtension = url.pathExtension.lowercased()
        let isSupported = SupportedFileType.fromFileExtension(pathExtension) != nil
        
        if isSupported {
            // Additional validation - check file size (limit to 10MB)
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            return fileSize <= 10 * 1024 * 1024 // 10MB limit
        }
        
        return false
    }
    
    // MARK: - Private Methods
    
    private func extractTextFromHTML(_ html: String) throws -> String {
        // Simple HTML text extraction
        // In a production app, you'd use a proper HTML parser
        var text = html
        
        // Remove script and style tags and their content
        let scriptPattern = "<script[^>]*>[\\s\\S]*?</script>"
        let stylePattern = "<style[^>]*>[\\s\\S]*?</style>"
        
        text = text.replacingOccurrences(of: scriptPattern, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: stylePattern, with: "", options: .regularExpression)
        
        // Remove HTML tags
        let tagPattern = "<[^>]+>"
        text = text.replacingOccurrences(of: tagPattern, with: " ", options: .regularExpression)
        
        // Clean up whitespace
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return text
    }
    
    private func formatTranslationResult(_ result: BackTranslationResult) -> String {
        var output = "Translation Fiesta Swift - Back-Translation Result\n"
        output += "=" + String(repeating: "=", count: 50) + "\n\n"
        
        output += "Original English:\n\(result.originalEnglish)\n\n"
        output += "Japanese Translation:\n\(result.japanese)\n\n"
        output += "Back-translated English:\n\(result.backTranslatedEnglish)\n\n"
        
        output += "Quality Assessment:\n"
        output += "- BLEU Score: \(String(format: "%.3f", result.qualityAssessment.bleuScore))\n"
        output += "- Confidence Level: \(result.qualityAssessment.confidenceLevel.displayName)\n"
        output += "- Star Rating: \(result.qualityAssessment.starRating.displayString)\n\n"
        
        if !result.qualityAssessment.recommendations.isEmpty {
            output += "Recommendations:\n"
            for recommendation in result.qualityAssessment.recommendations {
                output += "- \(recommendation)\n"
            }
            output += "\n"
        }
        
        output += "Cost Information:\n"
        output += "- Total Characters: \(result.totalCost.characterCount)\n"
        output += "- Total Cost: $\(String(format: "%.4f", result.totalCost.costInUSD))\n"
        output += "- API Provider: \(result.totalCost.apiProvider.displayName)\n\n"
        
        output += "Timestamp: \(result.forwardTranslation.timestamp.formatted())\n"
        
        return output
    }
}

/// Batch processing service
public final class BatchProcessingService: BatchRepository {
    private let logger = Logger(label: "BatchProcessingService")
    private let fileRepository: FileRepository
    private let backTranslationUseCase: BackTranslationUseCase
    
    private var runningOperations: [UUID: Task<Void, Error>] = [:]
    
    public init(
        fileRepository: FileRepository,
        backTranslationUseCase: BackTranslationUseCase
    ) {
        self.fileRepository = fileRepository
        self.backTranslationUseCase = backTranslationUseCase
    }
    
    public func startBatchOperation(_ operation: BatchOperation) async throws -> AsyncThrowingStream<BatchProgress, Error> {
        logger.info("Starting batch operation", metadata: [
            "id": "\(operation.id)",
            "fileCount": "\(operation.files.count)",
            "sourceLanguage": "\(operation.sourceLanguage.rawValue)",
            "targetLanguage": "\(operation.targetLanguage.rawValue)"
        ])
        
        return AsyncThrowingStream { continuation in
            let task = Task<Void, Error> {
                var mutableOperation = operation
                mutableOperation.status = .running
                
                for (_, file) in operation.files.enumerated() {
                    let startTime = CFAbsoluteTimeGetCurrent()
                    
                    do {
                        let translationResult = try await backTranslationUseCase.execute(
                            text: file.content,
                            sourceLanguage: operation.sourceLanguage,
                            targetLanguage: operation.targetLanguage,
                            apiProvider: operation.apiProvider
                        )
                        
                        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
                        let batchResult = BatchTranslationResult(
                            fileId: file.id,
                            fileName: file.url.lastPathComponent,
                            success: true,
                            translationResult: translationResult,
                            processingTime: processingTime
                        )
                        
                        mutableOperation.results.append(batchResult)
                        mutableOperation.progress.recordSuccess()
                        
                        logger.debug("File processed successfully", metadata: [
                            "fileName": "\(file.url.lastPathComponent)",
                            "processingTime": "\(processingTime)"
                        ])
                        
                    } catch {
                        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
                        let batchResult = BatchTranslationResult(
                            fileId: file.id,
                            fileName: file.url.lastPathComponent,
                            success: false,
                            error: error.localizedDescription,
                            processingTime: processingTime
                        )
                        
                        mutableOperation.results.append(batchResult)
                        mutableOperation.progress.recordFailure()
                        
                        logger.error("File processing failed", metadata: [
                            "fileName": "\(file.url.lastPathComponent)",
                            "error": "\(error.localizedDescription)"
                        ])
                    }
                    
                    // Send progress update
                    continuation.yield(mutableOperation.progress)
                    
                    // Check for cancellation
                    if Task.isCancelled {
                        mutableOperation.status = .cancelled
                        mutableOperation.endTime = Date()
                        logger.info("Batch operation cancelled")
                        break
                    }
                }
                
                if !Task.isCancelled {
                    mutableOperation.status = .completed
                    mutableOperation.endTime = Date()
                    
                    logger.info("Batch operation completed", metadata: [
                        "successfulFiles": "\(mutableOperation.progress.successfulFiles)",
                        "failedFiles": "\(mutableOperation.progress.failedFiles)",
                        "totalTime": "\(mutableOperation.duration ?? 0)"
                    ])
                }
                
                continuation.finish()
                runningOperations.removeValue(forKey: operation.id)
            }
            
            runningOperations[operation.id] = task
            
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
    
    public func cancelBatchOperation(id: UUID) async throws {
        guard let task = runningOperations[id] else {
            throw TranslationError.invalidInput("Batch operation not found")
        }
        
        task.cancel()
        runningOperations.removeValue(forKey: id)
        
        logger.info("Batch operation cancelled", metadata: ["id": "\(id)"])
    }
    
    public func getBatchOperationStatus(id: UUID) async throws -> BatchOperation? {
        // In a real implementation, you'd store operation status
        return nil
    }
    
    public func getAllBatchOperations() async throws -> [BatchOperation] {
        // In a real implementation, you'd persist and return all operations
        return []
    }
}
