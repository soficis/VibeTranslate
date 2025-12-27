import XCTest
@testable import TranslationFiestaSwift

final class TranslationFiestaSwiftTests: XCTestCase {
    func testLocalProviderProperties() throws {
        XCTAssertEqual(APIProvider.localOffline.rawValue, "local")
        XCTAssertFalse(APIProvider.localOffline.requiresAPIKey)
        XCTAssertFalse(APIProvider.localOffline.hasCostTracking)
    }

    func testOfficialProviderIdentifiers() throws {
        XCTAssertEqual(APIProvider.googleCloudAPI.rawValue, "google_official")
        XCTAssertTrue(APIProvider.googleCloudAPI.legacyStorageKeys.contains("google_cloud"))
    }

    func testTranslationErrorDescriptions() throws {
        XCTAssertEqual(TranslationError.rateLimited.errorDescription, "Provider rate limited")
        XCTAssertEqual(TranslationError.blocked.errorDescription, "Provider blocked or captcha detected")
        XCTAssertEqual(TranslationError.invalidResponse("bad").errorDescription, "Invalid response: bad")
    }
}
