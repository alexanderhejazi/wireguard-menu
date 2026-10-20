import XCTest
@testable import Archway

final class UpdateCheckerTests: XCTestCase {
    func testComparesVersionComponentsNumerically() {
        XCTAssertTrue(UpdateChecker.isNewer("0.10.0", than: "0.9.0"))
        XCTAssertTrue(UpdateChecker.isNewer("1.0.0", than: "0.9.9"))
        XCTAssertFalse(UpdateChecker.isNewer("0.1.0", than: "0.1.0"))
        XCTAssertFalse(UpdateChecker.isNewer("0.9.0", than: "0.10.0"))
    }

    func testReadsVersionFromReleaseTag() throws {
        let json = #"{"tag_name": "v0.2.0", "html_url": "https://github.com/mnilsson/archway/releases/tag/v0.2.0"}"#
        let release = try JSONDecoder().decode(Release.self, from: Data(json.utf8))
        XCTAssertEqual(release.version, "0.2.0")
    }
}
