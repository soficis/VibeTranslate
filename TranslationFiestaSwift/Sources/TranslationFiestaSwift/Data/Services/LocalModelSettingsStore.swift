import Foundation

public struct LocalModelSettings: Codable {
    public var serviceUrl: String
    public var modelDir: String
    public var autoStart: Bool

    public init(serviceUrl: String = "", modelDir: String = "", autoStart: Bool = true) {
        self.serviceUrl = serviceUrl
        self.modelDir = modelDir
        self.autoStart = autoStart
    }
}

public final class LocalModelSettingsStore {
    private let key = "local_model_settings"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> LocalModelSettings {
        guard let data = defaults.data(forKey: key),
              let settings = try? JSONDecoder().decode(LocalModelSettings.self, from: data) else {
            return LocalModelSettings()
        }
        return settings
    }

    public func save(_ settings: LocalModelSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: key)
        }
    }
}
