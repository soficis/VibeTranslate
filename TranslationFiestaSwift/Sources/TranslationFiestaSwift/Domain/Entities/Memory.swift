import Foundation

/// Translation memory cache entry
public struct TranslationMemoryEntry: Equatable, Codable, Identifiable, Sendable {
    public let id: UUID
    public let sourceText: String
    public let translatedText: String
    public let sourceLanguage: Language
    public let targetLanguage: Language
    public var accessTime: Date
    public let creationTime: Date
    public var accessCount: Int
    
    public init(
        sourceText: String,
        translatedText: String,
        sourceLanguage: Language,
        targetLanguage: Language
    ) {
        self.id = UUID()
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.accessTime = Date()
        self.creationTime = Date()
        self.accessCount = 1
    }
    
    public mutating func recordAccess() {
        accessTime = Date()
        accessCount += 1
    }
    
    public var cacheKey: String {
        return "\(sourceText):\(sourceLanguage.rawValue):\(targetLanguage.rawValue)"
    }
}

/// Translation memory configuration
public struct TranslationMemoryConfig: Equatable, Codable, Sendable {
    public var maxCacheSize: Int
    public var persistencePath: String
    public var autoSaveInterval: TimeInterval
    
    public init(
        maxCacheSize: Int = 1000,
        persistencePath: String = "translation_memory.json",
        autoSaveInterval: TimeInterval = 300 // 5 minutes
    ) {
        self.maxCacheSize = maxCacheSize
        self.persistencePath = persistencePath
        self.autoSaveInterval = autoSaveInterval
    }
}

/// Translation memory statistics
public struct TranslationMemoryStats: Equatable, Codable, Sendable {
    public let totalEntries: Int
    public let maxCacheSize: Int
    public let cacheUtilization: Double
    public let totalHits: Int
    public let totalMisses: Int
    public let hitRate: Double
    public let averageLookupTime: TimeInterval
    public let lastPersistTime: Date?
    
    public init(
        totalEntries: Int,
        maxCacheSize: Int,
        totalHits: Int,
        totalMisses: Int,
        averageLookupTime: TimeInterval,
        lastPersistTime: Date?
    ) {
        self.totalEntries = totalEntries
        self.maxCacheSize = maxCacheSize
        self.cacheUtilization = maxCacheSize > 0 ? Double(totalEntries) / Double(maxCacheSize) * 100.0 : 0.0
        self.totalHits = totalHits
        self.totalMisses = totalMisses
        
        let totalLookups = totalHits + totalMisses
        self.hitRate = totalLookups > 0 ? Double(totalHits) / Double(totalLookups) * 100.0 : 0.0
        
        self.averageLookupTime = averageLookupTime
        self.lastPersistTime = lastPersistTime
    }
}

/// EPUB chapter information
public struct EPUBChapter: Equatable, Codable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let content: String
    public let order: Int
    public let wordCount: Int
    
    public init(id: String, title: String, content: String, order: Int) {
        self.id = id
        self.title = title
        self.content = content
        self.order = order
        self.wordCount = content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
    }
}

/// EPUB book metadata and chapters
public struct EPUBBook: Equatable, Codable, Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let author: String?
    public let publisher: String?
    public let language: String?
    public let chapters: [EPUBChapter]
    public let metadata: [String: String]
    
    public init(
        title: String,
        author: String? = nil,
        publisher: String? = nil,
        language: String? = nil,
        chapters: [EPUBChapter],
        metadata: [String: String] = [:]
    ) {
        self.id = UUID()
        self.title = title
        self.author = author
        self.publisher = publisher
        self.language = language
        self.chapters = chapters.sorted { $0.order < $1.order }
        self.metadata = metadata
    }
    
    public var totalWordCount: Int {
        return chapters.map(\.wordCount).reduce(0, +)
    }
    
    public var chapterCount: Int {
        return chapters.count
    }
}

/// Export format types
public enum ExportFormat: String, CaseIterable, Codable, Identifiable, Sendable {
    case pdf = "pdf"
    case docx = "docx"
    case html = "html"
    case txt = "txt"
    case json = "json"
    
    public var id: Self { self }
    
    public var displayName: String {
        switch self {
        case .pdf: return "PDF Document"
        case .docx: return "Word Document (DOCX)"
        case .html: return "HTML Web Page"
        case .txt: return "Plain Text"
        case .json: return "JSON Data"
        }
    }
    
    public var fileExtension: String {
        return rawValue
    }
    
    public var mimeType: String {
        switch self {
        case .pdf: return "application/pdf"
        case .docx: return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case .html: return "text/html"
        case .txt: return "text/plain"
        case .json: return "application/json"
        }
    }
}

/// Export configuration options
public struct ExportConfig: Equatable, Codable, Sendable {
    public let format: ExportFormat
    public let includeMetadata: Bool
    public let includeTimestamps: Bool
    public let customTemplate: String?
    public let outputFileName: String?
    
    public init(
        format: ExportFormat,
        includeMetadata: Bool = true,
        includeTimestamps: Bool = true,
        customTemplate: String? = nil,
        outputFileName: String? = nil
    ) {
        self.format = format
        self.includeMetadata = includeMetadata
        self.includeTimestamps = includeTimestamps
        self.customTemplate = customTemplate
        self.outputFileName = outputFileName
    }
}
