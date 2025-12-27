import Foundation
import Crypto
import Logging

/// Translation service implementation
public final class TranslationService: TranslationRepository {
    private let logger = Logger(label: "TranslationService")
    private let networkService: NetworkService
    private let secureStorage: SecureStorageRepository
    private let localSettingsStore: LocalModelSettingsStore
    
    public init(networkService: NetworkService, secureStorage: SecureStorageRepository) {
        self.networkService = networkService
        self.secureStorage = secureStorage
        self.localSettingsStore = LocalModelSettingsStore()
    }
    
    public func translate(
        text: String,
        sourceLanguage: Language,
        targetLanguage: Language,
        apiProvider: APIProvider
    ) async throws -> TranslationResult {
        logger.info("Starting translation", metadata: [
            "sourceLanguage": "\(sourceLanguage.rawValue)",
            "targetLanguage": "\(targetLanguage.rawValue)",
            "apiProvider": "\(apiProvider.rawValue)",
            "textLength": "\(text.count)"
        ])
        
        let translatedText: String
        let cost: TranslationCost?
        
        switch apiProvider {
        case .localOffline:
            translatedText = try await makeLocalClient().translate(
                text: text,
                source: sourceLanguage.rawValue,
                target: targetLanguage.rawValue
            )
            cost = nil

        case .googleUnofficialAPI:
            translatedText = try await translateWithUnofficialAPI(
                text: text,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            )
            cost = nil
            
        case .googleCloudAPI:
            let apiKey = try await getAPIKey(for: apiProvider)
            translatedText = try await translateWithOfficialAPI(
                text: text,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                apiKey: apiKey
            )
            cost = TranslationCost(
                characterCount: text.count,
                costInUSD: TranslationCost.calculateGoogleCloudCost(characterCount: text.count),
                apiProvider: apiProvider
            )
        }
        
        logger.info("Translation completed successfully")
        
        return TranslationResult(
            originalText: text,
            translatedText: translatedText,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            apiProvider: apiProvider,
            cost: cost
        )
    }

    private func makeLocalClient() -> LocalServiceClient {
        let settings = localSettingsStore.load()
        let config = LocalServiceConfiguration.fromSettings(settings)
        return LocalServiceClient(session: URLSession.shared, configuration: config)
    }
    
    public func backTranslate(
        text: String,
        sourceLanguage: Language,
        targetLanguage: Language,
        apiProvider: APIProvider
    ) async throws -> BackTranslationResult {
        logger.info("Starting back-translation")
        
        // Forward translation: source -> target
        let forwardResult = try await translate(
            text: text,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            apiProvider: apiProvider
        )
        
        // Backward translation: target -> source
        let backwardResult = try await translate(
            text: forwardResult.translatedText,
            sourceLanguage: targetLanguage,
            targetLanguage: sourceLanguage,
            apiProvider: apiProvider
        )
        
        // Calculate total cost
        let totalCost = TranslationCost(
            characterCount: (forwardResult.cost?.characterCount ?? 0) + (backwardResult.cost?.characterCount ?? 0),
            costInUSD: (forwardResult.cost?.costInUSD ?? 0.0) + (backwardResult.cost?.costInUSD ?? 0.0),
            apiProvider: apiProvider
        )
        
        // Assess quality
        let qualityAssessment = try await assessTranslationQuality(
            original: text,
            backTranslated: backwardResult.translatedText
        )
        
        logger.info("Back-translation completed", metadata: [
            "qualityScore": "\(qualityAssessment.bleuScore)",
            "totalCost": "\(totalCost.costInUSD)"
        ])
        
        return BackTranslationResult(
            originalEnglish: sourceLanguage == .english ? text : backwardResult.translatedText,
            japanese: targetLanguage == .japanese ? forwardResult.translatedText : text,
            backTranslatedEnglish: sourceLanguage == .english ? backwardResult.translatedText : text,
            forwardTranslation: forwardResult,
            backwardTranslation: backwardResult,
            qualityAssessment: qualityAssessment,
            totalCost: totalCost
        )
    }
    
    private func translateWithUnofficialAPI(
        text: String,
        sourceLanguage: Language,
        targetLanguage: Language
    ) async throws -> String {
        let url = URL(string: "https://translate.googleapis.com/translate_a/single")!
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "client", value: "gtx"),
            URLQueryItem(name: "sl", value: sourceLanguage.rawValue),
            URLQueryItem(name: "tl", value: targetLanguage.rawValue),
            URLQueryItem(name: "dt", value: "t"),
            URLQueryItem(name: "q", value: text)
        ]
        
        guard let requestURL = components.url else {
            throw TranslationError.invalidInput("Failed to create request URL")
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.setValue("application/json,text/plain,*/*", forHTTPHeaderField: "Accept")
        if let userAgent = ProcessInfo.processInfo.environment["TF_UNOFFICIAL_USER_AGENT"],
           !userAgent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }

        let maxAttempts = 3
        var lastError: Error = TranslationError.networkError("Unknown error")

        for attempt in 1...maxAttempts {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw TranslationError.networkError("Invalid response type")
                }

                if http.statusCode == 429 {
                    if attempt < maxAttempts {
                        let delay = backoffDelay(attempt: attempt)
                        try await Task.sleep(nanoseconds: delay)
                        continue
                    }
                    throw TranslationError.rateLimited
                }

                if http.statusCode == 403 {
                    throw TranslationError.blocked
                }

                guard 200...299 ~= http.statusCode else {
                    throw TranslationError.invalidResponse("HTTP \(http.statusCode)")
                }

                guard let bodyString = String(data: data, encoding: .utf8), !bodyString.isEmpty else {
                    throw TranslationError.invalidResponse("Empty response body")
                }

                let lowered = bodyString.lowercased()
                if lowered.contains("<html") || lowered.contains("captcha") {
                    throw TranslationError.blocked
                }

                // Parse the unofficial API response
                guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [Any],
                      let translationsArray = jsonArray.first as? [Any] else {
                    throw TranslationError.invalidResponse("Unexpected JSON root")
                }

                var output = ""
                for item in translationsArray {
                    if let segment = item as? [Any],
                       let part = segment.first as? String {
                        output.append(part)
                    }
                }

                if output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    throw TranslationError.invalidResponse("No translation segments")
                }

                return output
            } catch {
                lastError = error
                if attempt < maxAttempts, (error is TranslationError) {
                    let delay = backoffDelay(attempt: attempt)
                    try await Task.sleep(nanoseconds: delay)
                    continue
                }
                throw error
            }
        }

        throw lastError
    }

    private func backoffDelay(attempt: Int) -> UInt64 {
        let baseMs = min(2000.0, 200.0 * pow(2.0, Double(attempt - 1)))
        let jitter = Double.random(in: 0...200)
        return UInt64((baseMs + jitter) * 1_000_000)
    }
    
    private func translateWithOfficialAPI(
        text: String,
        sourceLanguage: Language,
        targetLanguage: Language,
        apiKey: String
    ) async throws -> String {
        let url = URL(string: "https://translation.googleapis.com/language/translate/v2")!
        
        let requestBody: [String: Any] = [
            "q": text,
            "source": sourceLanguage.rawValue,
            "target": targetLanguage.rawValue,
            "format": "text"
        ]
        
        let requestData = try JSONSerialization.data(withJSONObject: requestBody)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = requestData
        
        let response = try await networkService.performRequest(request: request)
        
        // Parse the official API response
        guard let json = try JSONSerialization.jsonObject(with: response) as? [String: Any],
              let data = json["data"] as? [String: Any],
              let translations = data["translations"] as? [[String: Any]],
              let firstTranslation = translations.first,
              let translatedText = firstTranslation["translatedText"] as? String else {
            throw TranslationError.invalidInput("Failed to parse translation response")
        }
        
        return translatedText
    }
    
    private func getAPIKey(for provider: APIProvider) async throws -> String {
        guard let apiKey = try await secureStorage.getAPIKey(for: provider) else {
            throw TranslationError.invalidAPIKey(provider)
        }
        return apiKey
    }
    
    private func assessTranslationQuality(
        original: String,
        backTranslated: String
    ) async throws -> QualityAssessment {
        // Simplified BLEU score calculation
        let bleuScore = calculateSimpleBLEUScore(reference: original, candidate: backTranslated)
        
        let recommendations = generateQualityRecommendations(
            bleuScore: bleuScore,
            originalLength: original.count,
            backTranslatedLength: backTranslated.count
        )
        
        return QualityAssessment(bleuScore: bleuScore, recommendations: recommendations)
    }
    
    private func calculateSimpleBLEUScore(reference: String, candidate: String) -> Double {
        // Simplified BLEU score implementation
        // In a production app, you'd use a more sophisticated algorithm
        let referenceWords = reference.lowercased().components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        let candidateWords = candidate.lowercased().components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        guard !referenceWords.isEmpty && !candidateWords.isEmpty else {
            return 0.0
        }
        
        let referenceSet = Set(referenceWords)
        let candidateSet = Set(candidateWords)
        let intersection = referenceSet.intersection(candidateSet)
        
        let precision = Double(intersection.count) / Double(candidateSet.count)
        let recall = Double(intersection.count) / Double(referenceSet.count)
        
        guard precision + recall > 0 else { return 0.0 }
        
        let f1Score = 2 * (precision * recall) / (precision + recall)
        
        // Apply length penalty
        let lengthRatio = Double(candidateWords.count) / Double(referenceWords.count)
        let lengthPenalty = lengthRatio > 1.0 ? (1.0 / lengthRatio) : lengthRatio
        
        return f1Score * lengthPenalty
    }
    
    private func generateQualityRecommendations(
        bleuScore: Double,
        originalLength: Int,
        backTranslatedLength: Int
    ) -> [String] {
        var recommendations: [String] = []
        
        if bleuScore < 0.3 {
            recommendations.append("Consider reviewing the translation for accuracy")
            recommendations.append("The back-translation shows significant differences from the original")
        }
        
        let lengthDifference = abs(originalLength - backTranslatedLength)
        let lengthRatio = Double(lengthDifference) / Double(originalLength)
        
        if lengthRatio > 0.5 {
            recommendations.append("Large difference in text length detected")
            recommendations.append("This may indicate translation quality issues")
        }
        
        if bleuScore > 0.7 {
            recommendations.append("High quality translation detected")
            recommendations.append("The meaning appears to be well preserved")
        }
        
        return recommendations
    }
}

/// Network service for HTTP requests
public final class NetworkService {
    private let session: URLSession
    private let logger = Logger(label: "NetworkService")
    
    public init(session: URLSession = .shared) {
        self.session = session
    }
    
    public func performRequest(url: URL) async throws -> Data {
        let request = URLRequest(url: url)
        return try await performRequest(request: request)
    }
    
    public func performRequest(request: URLRequest) async throws -> Data {
        logger.info("Performing network request", metadata: [
            "url": "\(request.url?.absoluteString ?? "unknown")",
            "method": "\(request.httpMethod ?? "GET")"
        ])
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TranslationError.networkError("Invalid response type")
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                logger.error("HTTP error", metadata: [
                    "statusCode": "\(httpResponse.statusCode)"
                ])
                
                switch httpResponse.statusCode {
                case 401:
                    throw TranslationError.invalidAPIKey(.googleCloudAPI)
                case 429:
                    throw TranslationError.quotaExceeded
                default:
                    throw TranslationError.networkError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            logger.info("Network request completed successfully", metadata: [
                "responseSize": "\(data.count)"
            ])
            
            return data
        } catch {
            logger.error("Network request failed", metadata: [
                "error": "\(error)"
            ])
            throw TranslationError.networkError(error.localizedDescription)
        }
    }
}
