import XCTest
#if canImport(FLEXReplicaCore)
@testable import FLEXReplicaCore
#endif

final class FLEXReplicaCoreTests: XCTestCase {
    func testPreferencesRoundTrip() {
        let suiteName = "FLEXReplicaTests.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }
        let store = PreferencesStore(defaults: suite)
        store.value = InspectorPreferences(showsPrivateClasses: true, showsAddresses: true,
                                           panelOpacity: 0.8, accentColorHex: "#FF00AA")
        XCTAssertEqual(store.value.accentColorHex, "#FF00AA")
        XCTAssertTrue(store.value.showsPrivateClasses)
        XCTAssertTrue(store.value.showsAddresses)
        XCTAssertEqual(store.value.panelOpacity, 0.8, accuracy: 0.001)
    }

    func testPreferencesDefaultWhenStorageIsEmpty() {
        let suiteName = "FLEXReplicaTests.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }
        let value = PreferencesStore(defaults: suite).value
        XCTAssertEqual(value, InspectorPreferences())
    }

    func testBrowserIsConstructible() {
        let browser = RuntimeBrowser()
        #if canImport(ObjectiveC)
        let info = browser.info(for: "NSObject")
        XCTAssertNotNil(info)
        XCTAssertFalse(browser.methods(for: "NSObject").isEmpty)
        #else
        XCTAssertTrue(browser.classes().isEmpty)
        #endif
    }

    #if canImport(ObjectiveC) && canImport(UIKit)
    func testBrowserExposesPropertyMetadata() {
        let properties = RuntimeBrowser().info(for: "UIView")?.properties ?? []
        XCTAssertFalse(properties.isEmpty)
    }
    #endif
}
