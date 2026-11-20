import XCTest
#if canImport(UIKit)
import UIKit
#endif
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
    func testViewHierarchyExpandsChildrenAndSkipsWindowObjectSnapshot() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        let label = UILabel(frame: CGRect(x: 10, y: 10, width: 200, height: 40))
        window.addSubview(label)
        let session = InspectorSession()
        session.inspectViewTree(window)

        let root = try XCTUnwrap(session.rootViewTree)
        let labelNode = try XCTUnwrap(root.children.first { $0.className == NSStringFromClass(UILabel.self) })
        session.inspectView(withID: root.id, in: window)
        XCTAssertNil(session.selectedObject)
        XCTAssertNotNil(session.patchActionError)

        session.inspectView(withID: labelNode.id, in: window)
        XCTAssertEqual(session.selectedObject?.className, NSStringFromClass(UILabel.self))
    }

    @MainActor
    func testTextCatalogFindsUIKitStringsAndButtonTitlePatchToggles() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 360, height: 720))
        window.isHidden = false
        let label = UILabel()
        label.text = "Visible label"
        let field = UITextField()
        field.text = "Field value"
        field.placeholder = "Field placeholder"
        let textView = UITextView()
        textView.text = "Text view value"
        let button = UIButton(type: .system)
        button.setTitle("Button title", for: .normal)
        let segmented = UISegmentedControl(items: ["First", "Second"])
        let hiddenLabel = UILabel()
        hiddenLabel.text = "Hidden label"
        hiddenLabel.isHidden = true
        let controls: [UIView] = [label, field, textView, button, segmented, hiddenLabel]
        controls.forEach { window.addSubview($0) }

        let elements = ViewHierarchyInspector().textElements(from: window)
        XCTAssertTrue(elements.contains { $0.source == "UILabel.text" && $0.value == "Visible label" })
        XCTAssertTrue(elements.contains { $0.source == "UITextField.placeholder" && $0.value == "Field placeholder" })
        XCTAssertTrue(elements.contains { $0.value == "Text view value" })
        XCTAssertTrue(elements.contains { $0.source == "UIButton.title[normal]" && $0.value == "Button title" })
        XCTAssertTrue(elements.contains { $0.source == "UISegmentedControl.segment[0]" && $0.value == "First" })
        XCTAssertFalse(elements.contains { $0.value == "Hidden label" })

        let buttonElement = try XCTUnwrap(elements.first { $0.source == "UIButton.title[normal]" })
        let suiteName = "FLEXReplicaTextPatchTests.\(UUID().uuidString)"
        let suite = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { suite.removePersistentDomain(forName: suiteName) }
        let store = FLEXReplicaPatchStore(defaults: suite, storageKey: "test.button-title")
        let property = InspectedProperty(id: buttonElement.id, name: buttonElement.propertyName,
                                         attributes: "T@\"NSString\",N", valueDescription: buttonElement.value,
                                         isWritable: true, editableKind: .string)
        XCTAssertNil(store.createPatch(on: buttonElement.targetObject,
                                       snapshot: ObjectInspector().snapshot(buttonElement.targetObject),
                                       property: property, name: "Button title patch",
                                       replacementValue: .string("Changed button")))
        let patch = try XCTUnwrap(store.patches.first)
        XCTAssertNil(store.setActive(true, for: patch))
        XCTAssertEqual(button.title(for: .normal), "Changed button")
        XCTAssertNil(store.setActive(false, for: patch))
        XCTAssertEqual(button.title(for: .normal), "Button title")

        let restoredStore = FLEXReplicaPatchStore(defaults: suite, storageKey: "test.button-title")
        let restoredPatch = try XCTUnwrap(restoredStore.patches.first)
        button.setTitle("Changed button", for: .normal)
        XCTAssertNil(restoredStore.bind(restoredPatch, to: button, snapshot: ObjectInspector().snapshot(button)))
        XCTAssertNil(restoredStore.setActive(true, for: restoredPatch))
        XCTAssertEqual(button.title(for: .normal), "Changed button")
        XCTAssertNil(restoredStore.setActive(false, for: restoredPatch))
        XCTAssertEqual(button.title(for: .normal), "Changed button")
    }

    @MainActor
    func testConfigurationAndSegmentTitlesCanBePatched() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 360, height: 720))
        window.isHidden = false
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.plain()
        configuration.title = "Configured title"
        button.configuration = configuration
        let segmented = UISegmentedControl(items: ["First", "Second"])
        window.addSubview(button)
        window.addSubview(segmented)
        let elements = ViewHierarchyInspector().textElements(from: window)

        let suiteName = "FLEXReplicaControlTitleTests.\(UUID().uuidString)"
        let suite = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { suite.removePersistentDomain(forName: suiteName) }

        let configured = try XCTUnwrap(elements.first { $0.source == "UIButton.configuration.title" })
        let configStore = FLEXReplicaPatchStore(defaults: suite, storageKey: "test.configuration-title")
        let configProperty = InspectedProperty(id: configured.id, name: configured.propertyName,
                                               attributes: "T@\"NSString\",N", valueDescription: configured.value,
                                               isWritable: true, editableKind: .string)
        XCTAssertNil(configStore.createPatch(on: configured.targetObject,
                                             snapshot: ObjectInspector().snapshot(configured.targetObject),
                                             property: configProperty, name: "Config title",
                                             replacementValue: .string("Changed config")))
        let configPatch = try XCTUnwrap(configStore.patches.first)
        XCTAssertNil(configStore.setActive(true, for: configPatch))
        XCTAssertEqual(button.configuration?.title, "Changed config")
        XCTAssertNil(configStore.setActive(false, for: configPatch))
        XCTAssertEqual(button.configuration?.title, "Configured title")

        let segment = try XCTUnwrap(elements.first { $0.source == "UISegmentedControl.segment[1]" })
        let segmentStore = FLEXReplicaPatchStore(defaults: suite, storageKey: "test.segment-title")
        let segmentProperty = InspectedProperty(id: segment.id, name: segment.propertyName,
                                                attributes: "T@\"NSString\",N", valueDescription: segment.value,
                                                isWritable: true, editableKind: .string)
        XCTAssertNil(segmentStore.createPatch(on: segment.targetObject,
                                              snapshot: ObjectInspector().snapshot(segment.targetObject),
                                              property: segmentProperty, name: "Segment title",
                                              replacementValue: .string("Deux")))
        let segmentPatch = try XCTUnwrap(segmentStore.patches.first)
        XCTAssertNil(segmentStore.setActive(true, for: segmentPatch))
        XCTAssertEqual(segmented.titleForSegment(at: 1), "Deux")
        XCTAssertNil(segmentStore.setActive(false, for: segmentPatch))
        XCTAssertEqual(segmented.titleForSegment(at: 1), "Second")
    }

    @MainActor
    func testAttributedTextPatchRestoresOriginalFormatting() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 360, height: 720))
        window.isHidden = false
        let label = UILabel()
        let original = NSAttributedString(string: "Styled label", attributes: [
            .foregroundColor: UIColor.red,
            .font: UIFont.systemFont(ofSize: 18, weight: .semibold)
        ])
        label.attributedText = original
        window.addSubview(label)
        let element = try XCTUnwrap(ViewHierarchyInspector().textElements(from: window).first {
            $0.source == "UILabel.attributedText"
        })
        let suiteName = "FLEXReplicaAttributedTextTests.\(UUID().uuidString)"
        let suite = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { suite.removePersistentDomain(forName: suiteName) }
        let store = FLEXReplicaPatchStore(defaults: suite, storageKey: "test.attributed-text")
        let property = InspectedProperty(id: element.id, name: element.propertyName,
                                         attributes: "T@\"NSString\",N", valueDescription: element.value,
                                         isWritable: true, editableKind: .string)
        XCTAssertNil(store.createPatch(on: element.targetObject,
                                       snapshot: ObjectInspector().snapshot(element.targetObject),
                                       property: property, name: "Styled label patch",
                                       replacementValue: .string("Changed label")))
        let patch = try XCTUnwrap(store.patches.first)
        XCTAssertNil(store.setActive(true, for: patch))
        XCTAssertEqual(label.attributedText?.string, "Changed label")
        XCTAssertNil(store.setActive(false, for: patch))
        XCTAssertTrue(label.attributedText?.isEqual(to: original) == true)
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
