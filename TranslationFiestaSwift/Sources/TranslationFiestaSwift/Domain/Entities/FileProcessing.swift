import Foundation

/// Represents a file that can be translated
public struct TranslatableFile: Equatable, Codable, Identifiable {
    public let id: UUID
    public let url: URL
    public let content: String
    public let fileType: SupportedFileType
    public let size: Int64
    public let lastModified: Date
    
    public init(url: URL, content: String, fileType: SupportedFileType) throws {
        self.id = UUID()
        self.url = url
        self.content = content
        self.fileType = fileType
        
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        self.size = attributes[.size] as? Int64 ?? 0
        self.lastModified = attributes[.modificationDate] as? Date ?? Date()
    }
}

/// Supported file types for import and processing
public enum SupportedFileType: String, CaseIterable, Codable {
    case text = "txt"
    case markdown = "md"
    case html = "html"
    case epub = "epub"
    
    public var displayName: String {
        switch self {
        case .text: return "Text File"
        case .markdown: return "Markdown File"
        case .html: return "HTML File"
        case .epub: return "EPUB E-book"
        }
    }
    
    public var fileExtensions: [String] {
        switch self {
        case .text: return ["txt"]
        case .markdown: return ["md", "markdown"]
        case .html: return ["html", "htm"]
        case .epub: return ["epub"]
        }
    }
    
    public static func fromFileExtension(_ extension: String) -> SupportedFileType? {
        let lowercased = `extension`.lowercased()
        return allCases.first { fileType in
            fileType.fileExtensions.contains(lowercased)
        }
    }
}

/// Batch processing operation for multiple files
public struct BatchOperation: Equatable, Identifiable {
    public let id: UUID
    public let files: [TranslatableFile]
    public let sourceLanguage: Language
    public let targetLanguage: Language
    public let apiProvider: APIProvider
    public let startTime: Date
    public var endTime: Date?
    public var status: BatchStatus
    public var progress: BatchProgress
    public var results: [BatchTranslationResult]
    
    public init(
        files: [TranslatableFile],
        sourceLanguage: Language,
        targetLanguage: Language,
        apiProvider: APIProvider
    ) {
        self.id = UUID()
        self.files = files
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.apiProvider = apiProvider
        self.startTime = Date()
        self.endTime = nil
        self.status = .pending
        self.progress = BatchProgress(totalFiles: files.count)
        self.results = []
    }
    
    public var duration: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }
    
    public var isCompleted: Bool {
        return status == .completed || status == .cancelled || status == .failed
    }
}

/// Status of a batch operation
public enum BatchStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case running = "running"
    case completed = "completed"
    case cancelled = "cancelled"
    case failed = "failed"
    
    public var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .running: return "Running"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        case .failed: return "Failed"
        }
    }
}

/// Progress tracking for batch operations
public struct BatchProgress: Equatable, Codable {
    public let totalFiles: Int
    public var processedFiles: Int
    public var successfulFiles: Int
    public var failedFiles: Int
    
    public init(totalFiles: Int) {
        self.totalFiles = totalFiles
        self.processedFiles = 0
        self.successfulFiles = 0
        self.failedFiles = 0
    }
    
    public var percentComplete: Double {
        guard totalFiles > 0 else { return 0.0 }
        return Double(processedFiles) / Double(totalFiles) * 100.0
    }
    
    public var isComplete: Bool {
        return processedFiles >= totalFiles
    }
    
    public mutating func recordSuccess() {
        processedFiles += 1
        successfulFiles += 1
    }
    
    public mutating func recordFailure() {
        processedFiles += 1
        failedFiles += 1
    }
}

/// Result of translating a single file in a batch operation
public struct BatchTranslationResult: Equatable, Codable, Identifiable {
    public let id: UUID
    public let fileId: UUID
    public let fileName: String
    public let success: Bool
    public let translationResult: BackTranslationResult?
    public let error: String?
    public let processingTime: TimeInterval
    
    public init(
        fileId: UUID,
        fileName: String,
        success: Bool,
        translationResult: BackTranslationResult? = nil,
        error: String? = nil,
        processingTime: TimeInterval
    ) {
        self.id = UUID()
        self.fileId = fileId
        self.fileName = fileName
        self.success = success
        self.translationResult = translationResult
        self.error = error
        self.processingTime = processingTime
    }
}