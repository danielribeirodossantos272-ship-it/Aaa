import Foundation
import Combine

#if canImport(UIKit)
import UIKit
#endif

@MainActor
public final class InspectorSession: ObservableObject {
    @Published public private(set) var matchingClasses: [RuntimeClassInfo] = []
    @Published public private(set) var selectedClass: RuntimeClassInfo?
    @Published public private(set) var selectedObject: ObjectSnapshot?
    @Published public private(set) var rootViewTree: ViewNode?
    @Published public private(set) var patchActionError: String?

    public let browser = RuntimeBrowser()
    public let objectInspector = ObjectInspector()
    public let patchStore = FLEXReplicaPatchStore.shared
    private weak var inspectedObject: AnyObject?

    #if canImport(UIKit)
    public let viewInspector = ViewHierarchyInspector()
    #endif

    public init() {}

    public func searchClasses(_ query: String) {
        matchingClasses = browser.classNames(matching: query).map { name in
            RuntimeClassInfo(id: name, name: name, superclass: nil, methods: [], properties: [])
        }
        selectedClass = nil
    }

    public func selectClass(_ name: String) {
        selectedClass = browser.info(for: name)
    }

    public func methods(for className: String, classMethods: Bool = false) -> [RuntimeMethodInfo] {
        browser.methods(for: className, classMethods: classMethods)
    }

    public func inspect(_ object: AnyObject) {
        inspectedObject = object
        selectedObject = objectInspector.snapshot(object)
        patchActionError = nil
    }

    public func refreshSelectedObject() {
        guard let object = inspectedObject else {
            selectedObject = nil
            return
        }
        selectedObject = objectInspector.snapshot(object)
    }

    @discardableResult
    public func createPropertyPatch(for property: InspectedProperty, name: String, rawValue: String) -> Bool {
        guard let object = inspectedObject, let snapshot = selectedObject else {
            patchActionError = "Selecione novamente o objeto antes de criar um patch."
            return false
        }
        guard let kind = property.editableKind,
              let value = FLEXReplicaPatchValue.parse(rawValue, as: kind) else {
            patchActionError = "Digite um valor válido para \(property.editableKind?.label ?? "esta propriedade")."
            return false
        }
        if let error = patchStore.createPatch(on: object, snapshot: snapshot,
                                              property: property, name: name,
                                              replacementValue: value) {
            patchActionError = error
            return false
        }
        patchActionError = nil
        refreshSelectedObject()
        return true
    }

    @discardableResult
    public func bindPropertyPatchToSelectedObject(_ patch: FLEXReplicaPropertyPatch) -> Bool {
        guard let object = inspectedObject, let snapshot = selectedObject else {
            patchActionError = "Selecione uma view na aba Views antes de vincular o patch."
            return false
        }
        if let error = patchStore.bind(patch, to: object, snapshot: snapshot) {
            patchActionError = error
            return false
        }
        patchActionError = nil
        refreshSelectedObject()
        return true
    }

    @discardableResult
    public func setPatchActive(_ isActive: Bool, for patch: FLEXReplicaPropertyPatch) -> Bool {
        if let error = patchStore.setActive(isActive, for: patch) {
            patchActionError = error
            return false
        }
        patchActionError = nil
        refreshSelectedObject()
        return true
    }

    @discardableResult
    public func removePatch(_ patch: FLEXReplicaPropertyPatch) -> Bool {
        if let error = patchStore.remove(patch) {
            patchActionError = error
            return false
        }
        patchActionError = nil
        refreshSelectedObject()
        return true
    }

    #if canImport(UIKit)
    public func inspectViewTree(_ root: UIView) {
        rootViewTree = viewInspector.tree(from: root)
    }

    public func inspectView(withID id: String, in root: UIView) {
        guard let view = viewInspector.view(withID: id, in: root) else { return }
        inspect(view)
    }

    public func selectView(atWindowPoint point: CGPoint, in root: UIView) -> UIView? {
        viewInspector.view(atWindowPoint: point, in: root)
    }
    #endif
}
