import Foundation
import Logging

public struct LocalServiceConfiguration {
    public let baseURL: URL
    public let modelDir: String
    public let autoStart: Bool

    public init(baseURL: URL, modelDir: String, autoStart: Bool) {
        self.baseURL = baseURL
        self.modelDir = modelDir
        self.autoStart = autoStart
    }

    public static func fromEnvironment() -> LocalServiceConfiguration {
        let rawUrl = ProcessInfo.processInfo.environment["TF_LOCAL_URL"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlString = (rawUrl?.isEmpty == false ? rawUrl! : "http://127.0.0.1:5055")
        let url = URL(string: urlString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))) ?? URL(string: "http://127.0.0.1:5055")!

        let rawAuto = ProcessInfo.processInfo.environment["TF_LOCAL_AUTOSTART"]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let autoStart: Bool
        if let rawAuto, rawAuto == "0" || rawAuto == "false" || rawAuto == "no" {
            autoStart = false
        } else {
            autoStart = true
        }

        let modelDir = ProcessInfo.processInfo.environment["TF_LOCAL_MODEL_DIR"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return LocalServiceConfiguration(baseURL: url, modelDir: modelDir, autoStart: autoStart)
    }

    public static func fromSettings(_ settings: LocalModelSettings) -> LocalServiceConfiguration {
        let trimmedUrl = settings.serviceUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = URL(string: trimmedUrl.isEmpty ? "http://127.0.0.1:5055" : trimmedUrl) ?? URL(string: "http://127.0.0.1:5055")!
        return LocalServiceConfiguration(baseURL: url, modelDir: settings.modelDir, autoStart: settings.autoStart)
    }
}

public final class LocalServiceClient {
    private let logger = Logger(label: "LocalServiceClient")
    private let session: URLSession
    private let configuration: LocalServiceConfiguration
    private var started = false
    private let lock = NSLock()

    public init(session: URLSession = .shared, configuration: LocalServiceConfiguration = .fromEnvironment()) {
        self.session = session
        self.configuration = configuration
    }

    public func translate(text: String, source: String, target: String) async throws -> String {
        try await ensureAvailable()

        let payload: [String: String] = [
            "text": text,
            "source_lang": source,
            "target_lang": target
        ]

        let data = try JSONSerialization.data(withJSONObject: payload)
        var request = URLRequest(url: configuration.baseURL.appendingPathComponent("translate"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let (responseData, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw TranslationError.networkError("Invalid response from local service")
        }
        guard 200...299 ~= http.statusCode else {
            throw TranslationError.networkError("Local service HTTP \(http.statusCode)")
        }

        let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any]
        if let error = json?["error"] as? [String: Any],
           let message = error["message"] as? String {
            throw TranslationError.networkError(message)
        }
        if let translated = json?["translated_text"] as? String, !translated.isEmpty {
            return translated
        }
        throw TranslationError.networkError("Local service returned empty translation")
    }

    private func ensureAvailable() async throws {
        if try await checkHealth() {
            return
        }
        guard configuration.autoStart else {
            throw TranslationError.networkError("Local service unavailable and autostart disabled")
        }
        startLocalService()
        for _ in 0..<10 {
            if try await checkHealth() {
                return
            }
            try await Task.sleep(nanoseconds: 250_000_000)
        }
        throw TranslationError.networkError("Local service did not become healthy")
    }

    private func checkHealth() async throws -> Bool {
        let url = configuration.baseURL.appendingPathComponent("health")
        let (responseData, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, 200...299 ~= http.statusCode else {
            return false
        }
        let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any]
        let status = json?["status"] as? String
        return status?.lowercased() == "ok"
    }

    private func startLocalService() {
        lock.lock()
        defer { lock.unlock() }
        if started { return }

        let scriptEnv = ProcessInfo.processInfo.environment["TF_LOCAL_SCRIPT"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let scriptPath = (scriptEnv?.isEmpty == false ? scriptEnv! : "TranslationFiestaLocal/local_service.py")
        let pythonEnv = ProcessInfo.processInfo.environment["PYTHON"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let pythonExe = (pythonEnv?.isEmpty == false ? pythonEnv! : "python")

        let process = Process()
        process.launchPath = pythonExe
        process.arguments = [scriptPath, "serve"]
        var env = ProcessInfo.processInfo.environment
        if !configuration.modelDir.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            env["TF_LOCAL_MODEL_DIR"] = configuration.modelDir.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let host = configuration.baseURL.host {
            env["TF_LOCAL_HOST"] = host
        }
        if configuration.baseURL.port != nil {
            env["TF_LOCAL_PORT"] = String(configuration.baseURL.port ?? 5055)
        }
        env["TF_LOCAL_AUTOSTART"] = configuration.autoStart ? "1" : "0"
        process.environment = env
        process.standardOutput = nil
        process.standardError = nil
        process.standardInput = nil
        do {
            try process.run()
            started = true
            logger.info("Local service start requested", metadata: ["script": "\(scriptPath)"])
        } catch {
            logger.error("Failed to start local service", metadata: ["error": "\(error)"])
        }
    }

    public func modelsStatus() async throws -> String {
        try await ensureAvailable()
        let url = configuration.baseURL.appendingPathComponent("models")
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, 200...299 ~= http.statusCode else {
            throw TranslationError.networkError("Local models status failed")
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    public func verifyModels() async throws -> String {
        try await postModelsAction(path: "models/verify")
    }

    public func removeModels() async throws -> String {
        try await postModelsAction(path: "models/remove")
    }

    public func installDefaultModels() async throws -> String {
        try await postModelsAction(path: "models/install")
    }

    private func postModelsAction(path: String) async throws -> String {
        try await ensureAvailable()
        let url = configuration.baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, 200...299 ~= http.statusCode else {
            throw TranslationError.networkError("Local models request failed")
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
