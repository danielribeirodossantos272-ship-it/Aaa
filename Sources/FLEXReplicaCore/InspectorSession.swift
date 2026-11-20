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

    public let browser = RuntimeBrowser()
    public let objectInspector = ObjectInspector()
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
        selectedObject = objectInspector.snapshot(object)
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
