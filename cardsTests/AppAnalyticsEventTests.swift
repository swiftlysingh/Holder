import XCTest
@testable import Holder

final class AppAnalyticsEventTests: XCTestCase {
    func testCardEventsContainOnlyWorkflowProperties() {
        let events: [AppAnalyticsEvent] = [
            .cardAddStarted,
            .cardSaveCompleted(operation: .create, inputMethod: .manual),
            .cardSaveFailed(operation: .update, inputMethod: .scanner),
            .cardDeleted(location: .active),
            .cardDeleteFailed(location: .archived),
            .cardArchived,
            .cardArchiveFailed,
            .cardUnarchived,
            .cardUnarchiveFailed,
            .cardScanStarted,
            .cardScanCompleted,
            .cardScanPermissionDenied,
            .cardOpenedFromWidget
        ]
        let allowedProperties: Set<String> = ["operation", "input_method", "location"]

        for event in events {
            XCTAssertTrue(Set(event.properties.keys).isSubset(of: allowedProperties), event.name)
        }
    }
}
