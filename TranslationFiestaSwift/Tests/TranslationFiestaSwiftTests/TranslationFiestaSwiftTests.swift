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

    func testTranslationErrorDescriptions() throws {
        XCTAssertEqual(TranslationError.rateLimited.errorDescription, "Provider rate limited")
        XCTAssertEqual(TranslationError.blocked.errorDescription, "Provider blocked or captcha detected")
        XCTAssertEqual(TranslationError.invalidResponse("bad").errorDescription, "Invalid response: bad")
    }
}
