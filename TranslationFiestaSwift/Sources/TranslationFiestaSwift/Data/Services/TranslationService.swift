import Foundation
import Logging

/// Translation service implementation.
public final class TranslationService: TranslationRepository {
    private let logger = Logger(label: "TranslationService")

    public init() {}

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

        translatedText = try await translateWithUnofficialAPI(
            text: text,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        )

        logger.info("Translation completed successfully")

        return TranslationResult(
            originalText: text,
            translatedText: translatedText,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            apiProvider: apiProvider
        )
    }

    public func backTranslate(
        text: String,
        sourceLanguage: Language,
        targetLanguage: Language,
        apiProvider: APIProvider
    ) async throws -> BackTranslationResult {
        logger.info("Starting back-translation")

        let forwardResult = try await translate(
            text: text,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            apiProvider: apiProvider
        )

        let backwardResult = try await translate(
            text: forwardResult.translatedText,
            sourceLanguage: targetLanguage,
            targetLanguage: sourceLanguage,
            apiProvider: apiProvider
        )

        logger.info("Back-translation completed")

        return BackTranslationResult(
            originalEnglish: sourceLanguage == .english ? text : backwardResult.translatedText,
            japanese: targetLanguage == .japanese ? forwardResult.translatedText : text,
            backTranslatedEnglish: sourceLanguage == .english ? backwardResult.translatedText : text,
            forwardTranslation: forwardResult,
            backwardTranslation: backwardResult
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

                guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [Any],
                      let translationsArray = jsonArray.first as? [Any] else {
                    throw TranslationError.invalidResponse("Unexpected JSON structure")
                }

                var output = ""
                for item in translationsArray {
                    if let segment = item as? [Any], let part = segment.first as? String {
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
}
