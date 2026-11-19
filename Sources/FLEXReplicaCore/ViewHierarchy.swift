import Foundation
#if canImport(UIKit)
import UIKit
#endif

public struct ViewNode: Identifiable, Hashable, Sendable {
    public let id: String
    public let className: String
    public let frame: String
    public let isHidden: Bool
    public let alpha: Double
    public let children: [ViewNode]
}

#if canImport(UIKit)
public final class ViewHierarchyInspector {
    public init() {}

    public func tree(from root: UIView) -> ViewNode { makeNode(root) }

    /// `point` is expressed in the coordinate system of `root`.
    public func view(at point: CGPoint, in root: UIView) -> UIView? {
        guard root.bounds.contains(point), isVisible(root) else { return nil }
        for child in root.subviews.reversed() {
            let childPoint = child.convert(point, from: root)
            if let match = view(at: childPoint, in: child) { return match }
        }
        return root
    }

    /// Convenience overload for a point expressed in window/screen coordinates.
    public func view(atWindowPoint point: CGPoint, in root: UIView) -> UIView? {
        view(at: root.convert(point, from: nil), in: root)
    }

    private func isVisible(_ view: UIView) -> Bool {
        guard !view.isHidden, view.alpha > 0.01, view.window != nil || view.superview == nil else { return false }
        var current: UIView? = view.superview
        while let parent = current {
            guard !parent.isHidden, parent.alpha > 0.01 else { return false }
            current = parent.superview
        }
        return true
    }

    private func makeNode(_ view: UIView) -> ViewNode {
        ViewNode(id: ObjectIdentifier(view).debugDescription,
                 className: NSStringFromClass(type(of: view)),
                 frame: NSStringFromCGRect(view.frame),
                 isHidden: view.isHidden,
                 alpha: Double(view.alpha),
                 children: view.subviews.map(makeNode))
    }
}
#endif
