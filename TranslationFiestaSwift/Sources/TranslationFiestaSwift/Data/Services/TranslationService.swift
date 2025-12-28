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
        guard let url = URL(string: "https://translate.googleapis.com/translate_a/single") else {
            throw TranslationError.invalidInput("Invalid base URL for unofficial API")
        }
        
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw TranslationError.invalidInput("Failed to create URL components")
        }
        
        components.queryItems = [
            URLQueryItem(name: "client", value: "gtx"),
            URLQueryItem(name: "sl", value: sourceLanguage.rawValue),
            URLQueryItem(name: "tl", value: targetLanguage.rawValue),
            URLQueryItem(name: "dt", value: "t"),
            URLQueryItem(name: "q", value: text)
        ]
        
        guard let requestURL = components.url else {
            logger.error("Failed to construct full request URL", metadata: ["textLength": "\(text.count)"])
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
                        logger.warning("Rate limited, retrying...", metadata: ["attempt": "\(attempt)", "delayMs": "\(delay / 1_000_000)"])
                        try await Task.sleep(nanoseconds: delay)
                        continue
                    }
                    throw TranslationError.rateLimited
                }

                if http.statusCode == 403 {
                    logger.error("Access forbidden (403)", metadata: ["api": "unofficial"])
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
                    logger.error("Response contains HTML or CAPTCHA", metadata: ["api": "unofficial"])
                    throw TranslationError.blocked
                }

                // Parse the unofficial API response
                guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [Any],
                      let translationsArray = jsonArray.first as? [Any] else {
                    throw TranslationError.invalidResponse("Unexpected JSON structure")
                }

                var output = ""
                for item in translationsArray {
                    if let segment = item as? [Any],
                       let part = segment.first as? String {
                        output.append(part)
                    }
                }

                if output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    throw TranslationError.invalidResponse("No translation segments found")
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
        guard let url = URL(string: "https://translation.googleapis.com/language/translate/v2") else {
            throw TranslationError.invalidInput("Invalid official API URL")
        }
        
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
        
        let responseData = try await networkService.performRequest(request: request)
        
        do {
            let response = try JSONDecoder().decode(GoogleCloudTranslationResponse.self, from: responseData)
            guard let translatedText = response.data.translations.first?.translatedText else {
                throw TranslationError.invalidResponse("No translations in response")
            }
            return translatedText
        } catch {
            logger.error("Failed to decode official API response", metadata: ["error": "\(error)"])
            throw TranslationError.invalidResponse("Decoding failed: \(error.localizedDescription)")
        }
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
        let bleuScore = QualityScorer.calculateSimpleBLEUScore(reference: original, candidate: backTranslated)
        
        let recommendations = QualityScorer.generateQualityRecommendations(
            bleuScore: bleuScore,
            originalLength: original.count,
            backTranslatedLength: backTranslated.count
        )
        
        return QualityAssessment(bleuScore: bleuScore, recommendations: recommendations)
    }
}

// MARK: - API Response Models

private struct GoogleCloudTranslationResponse: Codable {
    let data: TranslationData
    
    struct TranslationData: Codable {
        let translations: [TranslationItem]
    }
    
    struct TranslationItem: Codable {
        let translatedText: String
        let detectedSourceLanguage: String?
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
