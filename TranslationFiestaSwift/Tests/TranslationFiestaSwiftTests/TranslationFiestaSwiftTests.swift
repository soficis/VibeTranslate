import XCTest
@testable import TranslationFiestaSwift

final class TranslationFiestaSwiftTests: XCTestCase {
    func testUnofficialProviderIdentifier() throws {
        XCTAssertEqual(APIProvider.googleUnofficialAPI.rawValue, "google_unofficial")
    }

    func testProviderDecodeRejectsUnknownValue() throws {
        let json = "\"google_cloud\"".data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(APIProvider.self, from: json))
    }

    func testProviderDecodeAcceptsAliases() throws {
        let aliases = [
            "google_unofficial",
            "unofficial",
            "google_unofficial_free",
            "google_free",
            "googletranslate",
            "",
            " GOOGLE_UNOFFICIAL "
        ]

        for alias in aliases {
            let json = "\"\(alias)\"".data(using: .utf8)!
            let provider = try JSONDecoder().decode(APIProvider.self, from: json)
            XCTAssertEqual(provider, .googleUnofficialAPI)
        }
    }

    func testTranslationErrorDescriptions() throws {
        XCTAssertEqual(TranslationError.rateLimited.errorDescription, "Provider rate limited")
        XCTAssertEqual(TranslationError.blocked.errorDescription, "Provider blocked or captcha detected")
        XCTAssertEqual(TranslationError.invalidResponse("bad").errorDescription, "Invalid response: bad")
    }

    func testPortableDataRootUsesTFAppHomeOverride() throws {
        let overridePath = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tf-swift-\(UUID().uuidString)", isDirectory: true)
            .path

        setenv("TF_APP_HOME", overridePath, 1)
        defer { unsetenv("TF_APP_HOME") }

        let resolved = try PortablePaths.dataRoot()
        XCTAssertEqual(resolved.path, overridePath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: overridePath))
    }

    func testPortableDataRootDefaultsBesideExecutable() throws {
        unsetenv("TF_APP_HOME")

        let executablePath = CommandLine.arguments.first ?? FileManager.default.currentDirectoryPath
        let expected = URL(fileURLWithPath: executablePath)
            .deletingLastPathComponent()
            .appendingPathComponent("data", isDirectory: true)
            .path

        let resolved = try PortablePaths.dataRoot()
        XCTAssertEqual(resolved.path, expected)
    }
}
