import Foundation

/// Represents the result of a translation operation.
public struct TranslationResult: Equatable, Codable, Sendable {
    public let originalText: String
    public let translatedText: String
    public let sourceLanguage: Language
    public let targetLanguage: Language
    public let timestamp: Date
    public let apiProvider: APIProvider

    public init(
        originalText: String,
        translatedText: String,
        sourceLanguage: Language,
        targetLanguage: Language,
        timestamp: Date = Date(),
        apiProvider: APIProvider
    ) {
        self.originalText = originalText
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.timestamp = timestamp
        self.apiProvider = apiProvider
    }
}

/// Represents a back-translation result (English -> Japanese -> English).
public struct BackTranslationResult: Equatable, Codable, Identifiable, Sendable {
    public let id: UUID
    public let originalEnglish: String
    public let japanese: String
    public let backTranslatedEnglish: String
    public let forwardTranslation: TranslationResult
    public let backwardTranslation: TranslationResult

    public init(
        id: UUID = UUID(),
        originalEnglish: String,
        japanese: String,
        backTranslatedEnglish: String,
        forwardTranslation: TranslationResult,
        backwardTranslation: TranslationResult
    ) {
        self.id = id
        self.originalEnglish = originalEnglish
        self.japanese = japanese
        self.backTranslatedEnglish = backTranslatedEnglish
        self.forwardTranslation = forwardTranslation
        self.backwardTranslation = backwardTranslation
    }
}

/// Supported languages for translation.
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

/// Translation providers available in the app.
public enum APIProvider: String, CaseIterable, Codable, Identifiable, Sendable {
    case googleUnofficialAPI = "google_unofficial"

    public var id: Self { self }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let value = APIProvider.fromStorage(raw) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported APIProvider value: \(raw)"
            )
        }
        self = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var storageKey: String { rawValue }

    public var displayName: String {
        switch self {
        case .googleUnofficialAPI: return "Google Translate (Unofficial / Free)"
        }
    }

    public static func fromStorage(_ raw: String?) -> APIProvider? {
        let normalized = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        switch normalized {
        case "google_unofficial", "unofficial", "google_unofficial_free", "google_free", "googletranslate", "":
            return .googleUnofficialAPI
        default:
            return nil
        }
    }
}
