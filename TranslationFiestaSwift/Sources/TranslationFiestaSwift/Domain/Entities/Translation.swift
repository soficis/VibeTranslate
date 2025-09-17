import Foundation

/// Represents the result of a translation operation
/// Following Clean Code: meaningful names, immutable data structures
public struct TranslationResult: Equatable, Codable {
    public let originalText: String
    public let translatedText: String
    public let sourceLanguage: Language
    public let targetLanguage: Language
    public let timestamp: Date
    public let apiProvider: APIProvider
    public let cost: TranslationCost?
    public let qualityScore: QualityScore?
    
    public init(
        originalText: String,
        translatedText: String,
        sourceLanguage: Language,
        targetLanguage: Language,
        timestamp: Date = Date(),
        apiProvider: APIProvider,
        cost: TranslationCost? = nil,
        qualityScore: QualityScore? = nil
    ) {
        self.originalText = originalText
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.timestamp = timestamp
        self.apiProvider = apiProvider
        self.cost = cost
        self.qualityScore = qualityScore
    }
}

/// Represents a back-translation result (English -> Japanese -> English)
public struct BackTranslationResult: Equatable, Codable, Identifiable {
    public let id: UUID
    public let originalEnglish: String
    public let japanese: String
    public let backTranslatedEnglish: String
    public let forwardTranslation: TranslationResult
    public let backwardTranslation: TranslationResult
    public let qualityAssessment: QualityAssessment
    public let totalCost: TranslationCost
    
    public init(
        id: UUID = UUID(),
        originalEnglish: String,
        japanese: String,
        backTranslatedEnglish: String,
        forwardTranslation: TranslationResult,
        backwardTranslation: TranslationResult,
        qualityAssessment: QualityAssessment,
        totalCost: TranslationCost
    ) {
        self.id = id
        self.originalEnglish = originalEnglish
        self.japanese = japanese
        self.backTranslatedEnglish = backTranslatedEnglish
        self.forwardTranslation = forwardTranslation
        self.backwardTranslation = backwardTranslation
        self.qualityAssessment = qualityAssessment
        self.totalCost = totalCost
    }
}

/// Supported languages for translation
public enum Language: String, CaseIterable, Codable, Identifiable, Sendable {
    case english = "en"
    case japanese = "ja"
    
    public var id: Self { self }
    
    public var displayName: String {
        switch self {
        case .english: return "English"
        case .japanese: return "Japanese"
        }
    }
    
    public var flag: String {
        switch self {
        case .english: return "🇺🇸"
        case .japanese: return "🇯🇵"
        }
    }
}

/// API providers for translation services
public enum APIProvider: String, CaseIterable, Codable, Identifiable, Sendable {
    case googleUnofficialAPI = "google_unofficial"
    case googleCloudAPI = "google_cloud"
    
    public var id: Self { self }
    
    public var displayName: String {
        switch self {
        case .googleUnofficialAPI: return "Google Translate (Unofficial)"
        case .googleCloudAPI: return "Google Cloud Translation API"
        }
    }
    
    public var requiresAPIKey: Bool {
        switch self {
        case .googleUnofficialAPI: return false
        case .googleCloudAPI: return true
        }
    }
    
    public var hasCostTracking: Bool {
        switch self {
        case .googleUnofficialAPI: return false
        case .googleCloudAPI: return true
        }
    }
}

/// Cost information for translation
public struct TranslationCost: Equatable, Codable {
    public let characterCount: Int
    public let costInUSD: Double
    public let apiProvider: APIProvider
    public let timestamp: Date
    
    public init(characterCount: Int, costInUSD: Double, apiProvider: APIProvider, timestamp: Date = Date()) {
        self.characterCount = characterCount
        self.costInUSD = costInUSD
        self.apiProvider = apiProvider
        self.timestamp = timestamp
    }
    
    /// Google Cloud Translation API pricing: $20 per 1 million characters
    public static func calculateGoogleCloudCost(characterCount: Int) -> Double {
        return Double(characterCount) * 20.0 / 1_000_000.0
    }
}

/// Quality assessment for translations
public struct QualityAssessment: Equatable, Codable {
    public let bleuScore: Double
    public let confidenceLevel: ConfidenceLevel
    public let starRating: StarRating
    public let recommendations: [String]
    
    public init(bleuScore: Double, recommendations: [String] = []) {
        self.bleuScore = bleuScore
        self.confidenceLevel = ConfidenceLevel.fromBLEUScore(bleuScore)
        self.starRating = StarRating.fromBLEUScore(bleuScore)
        self.recommendations = recommendations
    }
}

/// Quality score for individual translations
public struct QualityScore: Equatable, Codable {
    public let score: Double
    public let confidenceLevel: ConfidenceLevel
    
    public init(score: Double) {
        self.score = score
        self.confidenceLevel = ConfidenceLevel.fromBLEUScore(score)
    }
}

/// Five-tier confidence level system
public enum ConfidenceLevel: String, CaseIterable, Codable {
    case high = "high"
    case mediumHigh = "medium_high"
    case medium = "medium"
    case lowMedium = "low_medium"
    case low = "low"
    
    public var displayName: String {
        switch self {
        case .high: return "High"
        case .mediumHigh: return "Medium-High"
        case .medium: return "Medium"
        case .lowMedium: return "Low-Medium"
        case .low: return "Low"
        }
    }
    
    public static func fromBLEUScore(_ score: Double) -> ConfidenceLevel {
        switch score {
        case 0.7...: return .high
        case 0.5..<0.7: return .mediumHigh
        case 0.3..<0.5: return .medium
        case 0.1..<0.3: return .lowMedium
        default: return .low
        }
    }
}

/// Star rating system (1-5 stars)
public enum StarRating: Int, CaseIterable, Codable {
    case oneStar = 1
    case twoStars = 2
    case threeStars = 3
    case fourStars = 4
    case fiveStars = 5
    
    public var displayString: String {
        let filledStars = String(repeating: "★", count: rawValue)
        let emptyStars = String(repeating: "☆", count: 5 - rawValue)
        return filledStars + emptyStars
    }
    
    public static func fromBLEUScore(_ score: Double) -> StarRating {
        switch score {
        case 0.8...: return .fiveStars
        case 0.6..<0.8: return .fourStars
        case 0.4..<0.6: return .threeStars
        case 0.2..<0.4: return .twoStars
        default: return .oneStar
        }
    }
}