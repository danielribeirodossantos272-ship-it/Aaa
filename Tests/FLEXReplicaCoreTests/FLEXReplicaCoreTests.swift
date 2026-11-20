import XCTest
#if canImport(FLEXReplicaCore)
@testable import FLEXReplicaCore
#endif

#if canImport(ObjectiveC) && canImport(UIKit)
@objc private final class FLEXReplicaPatchFixture: NSObject {
    @objc dynamic var title: NSString = "Original"
}
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

    @MainActor
    func testNamedPropertyPatchPersistsAndCanBeToggled() throws {
        let suiteName = "FLEXReplicaPatchTests.\(UUID().uuidString)"
        let suite = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { suite.removePersistentDomain(forName: suiteName) }
        let target = FLEXReplicaPatchFixture()
        let snapshot = ObjectInspector().snapshot(target)
        let property = try XCTUnwrap(snapshot.properties.first { $0.name == "title" })
        let storageKey = "test.named-property-patch"
        let store = FLEXReplicaPatchStore(defaults: suite, storageKey: storageKey)

        XCTAssertNil(store.createPatch(on: target, snapshot: snapshot, property: property,
                                       name: "Título personalizado", replacementValue: .string("Alterado")))
        let patch = try XCTUnwrap(store.patches.first)
        XCTAssertEqual(patch.name, "Título personalizado")
        XCTAssertNil(store.setActive(true, for: patch))
        XCTAssertEqual(target.title as String, "Alterado")
        XCTAssertNil(store.setActive(false, for: patch))
        XCTAssertEqual(target.title as String, "Original")

        let restoredStore = FLEXReplicaPatchStore(defaults: suite, storageKey: storageKey)
        let savedPatch = try XCTUnwrap(restoredStore.patches.first)
        XCTAssertEqual(savedPatch.name, "Título personalizado")
        XCTAssertEqual(savedPatch.replacementValue, .string("Alterado"))
        XCTAssertFalse(savedPatch.isActive)
        XCTAssertFalse(savedPatch.isBound)
    }

    @MainActor
    func testNamedAlternativesForSamePropertyCannotBeActiveTogether() throws {
        let suiteName = "FLEXReplicaPatchTests.\(UUID().uuidString)"
        let suite = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { suite.removePersistentDomain(forName: suiteName) }
        let target = FLEXReplicaPatchFixture()
        let snapshot = ObjectInspector().snapshot(target)
        let property = try XCTUnwrap(snapshot.properties.first { $0.name == "title" })
        let store = FLEXReplicaPatchStore(defaults: suite, storageKey: "test.alternative-patches")

        XCTAssertNil(store.createPatch(on: target, snapshot: snapshot, property: property,
                                       name: "English", replacementValue: .string("Hello")))
        XCTAssertNil(store.createPatch(on: target, snapshot: snapshot, property: property,
                                       name: "Português", replacementValue: .string("Olá")))
        let english = try XCTUnwrap(store.patches.first { $0.name == "English" })
        let portuguese = try XCTUnwrap(store.patches.first { $0.name == "Português" })

        XCTAssertNil(store.setActive(true, for: english))
        XCTAssertNotNil(store.setActive(true, for: portuguese))
        XCTAssertEqual(target.title as String, "Hello")
        XCTAssertNil(store.setActive(false, for: english))
        XCTAssertNil(store.setActive(true, for: portuguese))
        XCTAssertEqual(target.title as String, "Olá")
        XCTAssertNil(store.setActive(false, for: portuguese))
        XCTAssertEqual(target.title as String, "Original")
    }
    #endif
}
