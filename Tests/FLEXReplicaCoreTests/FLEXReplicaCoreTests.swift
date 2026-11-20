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

    #if canImport(ObjectiveC)
    private func makeSuite() -> (defaults: UserDefaults, cleanup: () -> Void) {
        let name = "FLEXReplicaTests.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: name)!
        return (suite, { suite.removePersistentDomain(forName: name) })
    }

    @MainActor
    func testBoolPatchCanBeToggled() throws {
        let suite = makeSuite()
        defer { suite.cleanup() }
        let manager = PatchManager(defaults: suite.defaults)
        let subject = PatchSubject()
        XCTAssertFalse(subject.isReady())

        let patch = try manager.createPatch(className: "FLXPatchSubject", selector: "isReady",
                                            isClassMethod: false, returnValue: "YES")
        defer { manager.remove(id: patch.id) }
        XCTAssertTrue(subject.isReady())

        try manager.setEnabled(false, for: patch.id)
        XCTAssertFalse(subject.isReady())

        try manager.setEnabled(true, for: patch.id)
        XCTAssertTrue(subject.isReady())
    }

    @MainActor
    func testIntObjectAndClassMethodPatches() throws {
        let suite = makeSuite()
        defer { suite.cleanup() }
        let manager = PatchManager(defaults: suite.defaults)
        let subject = PatchSubject()

        let answer = try manager.createPatch(className: "FLXPatchSubject", selector: "answer",
                                             isClassMethod: false, returnValue: "42")
        let label = try manager.createPatch(className: "FLXPatchSubject", selector: "label",
                                            isClassMethod: false, returnValue: "patched")
        let version = try manager.createPatch(className: "FLXPatchSubject", selector: "version",
                                              isClassMethod: true, returnValue: "7")
        defer { [answer, label, version].forEach { manager.remove(id: $0.id) } }

        XCTAssertEqual(subject.answer(), 42)
        XCTAssertEqual(subject.label(), "patched")
        XCTAssertEqual(PatchSubject.version(), 7)

        manager.remove(id: answer.id)
        XCTAssertEqual(subject.answer(), 1)
    }

    @MainActor
    func testPatchesArePersisted() throws {
        let suite = makeSuite()
        defer { suite.cleanup() }
        let first = PatchManager(defaults: suite.defaults)
        let patch = try first.createPatch(className: "FLXPatchSubject", selector: "answer",
                                          isClassMethod: false, returnValue: "5")
        defer { first.remove(id: patch.id) }

        let second = PatchManager(defaults: suite.defaults)
        XCTAssertEqual(second.patches, [patch])
        XCTAssertTrue(second.patches[0].isEnabled)
    }

    @MainActor
    func testPatchErrors() {
        let suite = makeSuite()
        defer { suite.cleanup() }
        let manager = PatchManager(defaults: suite.defaults)

        XCTAssertThrowsError(try manager.createPatch(className: "NoSuchClassXYZ", selector: "foo",
                                                     isClassMethod: false, returnValue: nil)) {
            XCTAssertEqual($0 as? PatchError, .classNotFound("NoSuchClassXYZ"))
        }
        XCTAssertThrowsError(try manager.createPatch(className: "FLXPatchSubject", selector: "noSuchMethod",
                                                     isClassMethod: false, returnValue: nil)) {
            XCTAssertEqual($0 as? PatchError, .methodNotFound("noSuchMethod"))
        }
        XCTAssertThrowsError(try manager.createPatch(className: "FLXPatchSubject", selector: "frameValue",
                                                     isClassMethod: false, returnValue: nil)) {
            if case .unsupportedReturnType? = ($0 as? PatchError) {} else { XCTFail("wrong error: \($0)") }
        }
        XCTAssertTrue(manager.patches.isEmpty)
    }

    func testReturnKindParsing() {
        XCTAssertEqual(PatchReturnKind(encoding: "B"), .bool)
        XCTAssertEqual(PatchReturnKind(encoding: "q"), .int64)
        XCTAssertEqual(PatchReturnKind(encoding: "rn@"), .object)
        XCTAssertEqual(PatchReturnKind(encoding: "v"), .void)
        XCTAssertEqual(PatchReturnKind(encoding: "{CGRect={CGPoint=dd}{CGSize=dd}}"), .unsupported)
    }
    #endif
}

#if canImport(ObjectiveC)
/// Alvo dos testes de patch. `dynamic` força despacho via objc_msgSend (sem devirtualização).
@objc(FLXPatchSubject)
class PatchSubject: NSObject {
    @objc dynamic func isReady() -> Bool { false }
    @objc dynamic func answer() -> Int { 1 }
    @objc dynamic func label() -> String { "original" }
    @objc dynamic func frameValue() -> CGRect { .zero }
    @objc dynamic class func version() -> Int { 1 }
}
#endif
