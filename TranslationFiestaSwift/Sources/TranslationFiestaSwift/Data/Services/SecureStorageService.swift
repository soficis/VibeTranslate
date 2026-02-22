import Foundation
import Security
import Crypto
import Logging

/// Secure storage service for API keys and settings
public final class SecureStorageService: SecureStorageRepository {
    private let logger = Logger(label: "SecureStorageService")
    private let serviceName: String
    
    public init(serviceName: String = "TranslationFiestaSwift") {
        self.serviceName = serviceName
    }
    
    // MARK: - API Key Management
    
    public func storeAPIKey(_ key: String, for provider: APIProvider) async throws {
        let account = "api_key_\(provider.storageKey)"
        try await storeInKeychain(value: key, account: account)
        logger.info("API key stored successfully", metadata: ["provider": "\(provider.storageKey)"])
    }
    
    public func getAPIKey(for provider: APIProvider) async throws -> String? {
        let account = "api_key_\(provider.storageKey)"
        return try await getFromKeychain(account: account)
    }
    
    public func removeAPIKey(for provider: APIProvider) async throws {
        let account = "api_key_\(provider.storageKey)"
        try await removeFromKeychain(account: account)
        logger.info("API key removed", metadata: ["provider": "\(provider.storageKey)"])
    }
    
    public func hasAPIKey(for provider: APIProvider) async throws -> Bool {
        let apiKey = try await getAPIKey(for: provider)
        return apiKey != nil && !apiKey!.isEmpty
    }
    
    // MARK: - Settings Management
    
    public func storeSettings<T: Codable>(_ settings: T, key: String) async throws {
        let data = try JSONEncoder().encode(settings)
        let encodedData = data.base64EncodedString()
        
        let account = "settings_\(key)"
        try await storeInKeychain(value: encodedData, account: account)
        logger.info("Settings stored", metadata: ["key": "\(key)"])
    }
    
    public func getSettings<T: Codable>(type: T.Type, key: String) async throws -> T? {
        let account = "settings_\(key)"
        guard let encodedData = try await getFromKeychain(account: account),
              let data = Data(base64Encoded: encodedData) else {
            return nil
        }
        
        return try JSONDecoder().decode(type, from: data)
    }
    
    public func removeSettings(key: String) async throws {
        let account = "settings_\(key)"
        try await removeFromKeychain(account: account)
        logger.info("Settings removed", metadata: ["key": "\(key)"])
    }
    
    // MARK: - Keychain Operations
    
    private func storeInKeychain(value: String, account: String) async throws {
        // First, try to update existing item
        let updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]
        
        let updateAttributes: [String: Any] = [
            kSecValueData as String: value.data(using: .utf8)!
        ]
        
        let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)
        
        if updateStatus == errSecSuccess {
            return
        }
        
        // If update failed, add new item
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecValueData as String: value.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        
        guard addStatus == errSecSuccess else {
            logger.error("Failed to store in keychain", metadata: [
                "account": "\(account)",
                "status": "\(addStatus)"
            ])
            throw SecureStorageError.keychainError(addStatus)
        }
    }
    
    private func getFromKeychain(account: String) async throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return nil
            }
            logger.error("Failed to retrieve from keychain", metadata: [
                "account": "\(account)",
                "status": "\(status)"
            ])
            throw SecureStorageError.keychainError(status)
        }
        
        guard let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw SecureStorageError.dataCorruption
        }
        
        return value
    }
    
    private func removeFromKeychain(account: String) async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.error("Failed to remove from keychain", metadata: [
                "account": "\(account)",
                "status": "\(status)"
            ])
            throw SecureStorageError.keychainError(status)
        }
    }
}

/// Secure storage errors
public enum SecureStorageError: LocalizedError {
    case keychainError(OSStatus)
    case dataCorruption
    case encryptionFailed
    case decryptionFailed
    
    public var errorDescription: String? {
        switch self {
        case .keychainError(let status):
            return "Keychain error: \(status)"
        case .dataCorruption:
            return "Data corruption detected"
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data"
        }
    }
}
