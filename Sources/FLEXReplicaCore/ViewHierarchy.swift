import Foundation
#if canImport(UIKit)
import UIKit
import QuartzCore
import ObjectiveC.runtime
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
public struct FLEXReplicaTextElement: Identifiable {
    public let id: String
    public let className: String
    public let source: String
    public let value: String
    public let propertyName: String
    public let targetObject: AnyObject
}

public final class ViewHierarchyInspector {
    public init() {}

    public func tree(from root: UIView) -> ViewNode { makeNode(root) }

    public func view(withID id: String, in root: UIView) -> UIView? {
        if ObjectIdentifier(root).debugDescription == id { return root }
        for child in root.subviews {
            if let match = view(withID: id, in: child) { return match }
        }
        return nil
    }

    /// Returns string-bearing UIKit controls currently present below the active window.
    @MainActor
    public func textElements(from root: UIView) -> [FLEXReplicaTextElement] {
        var result: [FLEXReplicaTextElement] = []
        var seen = Set<String>()

        func add(target: AnyObject, source: String, propertyName: String, value: String?) {
            guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            let identity = ObjectIdentifier(target).debugDescription
            let id = "\(identity)|\(propertyName)"
            guard seen.insert(id).inserted else { return }
            let dynamicClass = object_getClass(target) ?? NSObject.self
            result.append(FLEXReplicaTextElement(id: id,
                                                 className: NSStringFromClass(dynamicClass),
                                                 source: source,
                                                 value: value,
                                                 propertyName: propertyName,
                                                 targetObject: target))
        }

        func stringValue(_ value: Any?) -> String? {
            if let attributed = value as? NSAttributedString { return attributed.string }
            if let string = value as? NSString { return string as String }
            return value as? String
        }

        func addTextControl(_ view: UIView) {
            if let label = view as? UILabel {
                if let attributed = label.attributedText, !attributed.string.isEmpty {
                    add(target: label, source: "UILabel.attributedText", propertyName: FLEXReplicaTextPatchKey.attributedText, value: attributed.string)
                } else {
                    add(target: label, source: "UILabel.text", propertyName: "text", value: label.text)
                }
            }

            if let field = view as? UITextField {
                if let attributed = field.attributedText, !attributed.string.isEmpty {
                    add(target: field, source: "UITextField.attributedText", propertyName: FLEXReplicaTextPatchKey.attributedText, value: attributed.string)
                } else {
                    add(target: field, source: "UITextField.text", propertyName: "text", value: field.text)
                }
                if let attributed = field.attributedPlaceholder, !attributed.string.isEmpty {
                    add(target: field, source: "UITextField.attributedPlaceholder", propertyName: FLEXReplicaTextPatchKey.attributedPlaceholder, value: attributed.string)
                } else {
                    add(target: field, source: "UITextField.placeholder", propertyName: "placeholder", value: field.placeholder)
                }
            }

            if let textView = view as? UITextView {
                if let attributed = textView.attributedText, !attributed.string.isEmpty {
                    add(target: textView, source: "UITextView.attributedText", propertyName: FLEXReplicaTextPatchKey.attributedText, value: attributed.string)
                } else {
                    add(target: textView, source: "UITextView.text", propertyName: "text", value: textView.text)
                }
            }

            if let searchBar = view as? UISearchBar {
                add(target: searchBar, source: "UISearchBar.text", propertyName: "text", value: searchBar.text)
                add(target: searchBar, source: "UISearchBar.placeholder", propertyName: "placeholder", value: searchBar.placeholder)
            }

            if let button = view as? UIButton {
                if let title = button.configuration?.title, !title.isEmpty {
                    add(target: button, source: "UIButton.configuration.title", propertyName: FLEXReplicaTextPatchKey.buttonConfigurationTitle, value: title)
                } else {
                    let states: [(String, UIControl.State)] = [
                        ("normal", .normal), ("selected", .selected),
                        ("highlighted", .highlighted), ("disabled", .disabled)
                    ]
                    for (label, state) in states {
                        if let attributed = button.attributedTitle(for: state), !attributed.string.isEmpty {
                            add(target: button, source: "UIButton.attributedTitle[\(label)]",
                                propertyName: FLEXReplicaTextPatchKey.buttonAttributedTitle(state.rawValue), value: attributed.string)
                        } else {
                            add(target: button, source: "UIButton.title[\(label)]",
                                propertyName: FLEXReplicaTextPatchKey.buttonTitle(state.rawValue), value: button.title(for: state))
                        }
                    }
                }
            }

            if let segmented = view as? UISegmentedControl {
                for index in 0..<segmented.numberOfSegments {
                    add(target: segmented, source: "UISegmentedControl.segment[\(index)]",
                        propertyName: FLEXReplicaTextPatchKey.segmentTitle(index), value: segmented.titleForSegment(at: index))
                }
            }

            if let bar = view as? UINavigationBar {
                for item in bar.items ?? [] {
                    add(target: item, source: "UINavigationItem.title", propertyName: "title", value: item.title)
                }
            }
            if let bar = view as? UITabBar {
                for item in bar.items ?? [] {
                    add(target: item, source: "UITabBarItem.title", propertyName: "title", value: item.title)
                }
            }
            if let bar = view as? UIToolbar {
                for item in bar.items ?? [] {
                    add(target: item, source: "UIBarButtonItem.title", propertyName: "title", value: item.title)
                }
            }
        }

        func belongsToInspector(_ view: UIView?) -> Bool {
            var current = view
            while let candidate = current {
                if candidate.accessibilityIdentifier == "FLEXReplicaPanelHost" ||
                    candidate.accessibilityIdentifier == "FLEXReplicaFloatingButton" ||
                    candidate.isHidden || candidate.alpha <= 0.01 {
                    return true
                }
                current = candidate.superview
            }
            return false
        }

        func layerIsVisible(_ layer: CALayer) -> Bool {
            var current: CALayer? = layer
            while let candidate = current {
                if candidate.isHidden || candidate.opacity <= 0.01 { return false }
                current = candidate.superlayer
            }
            return true
        }

        func visit(_ view: UIView) {
            guard !belongsToInspector(view) else { return }
            addTextControl(view)
            for child in view.subviews {
                if let button = view as? UIButton, child === button.titleLabel { continue }
                if let searchBar = view as? UISearchBar, child === searchBar.searchTextField { continue }
                visit(child)
            }
        }

        func visitLayers(_ layer: CALayer) {
            if let textLayer = layer as? CATextLayer {
                let owner = textLayer.delegate as? UIView
                if !belongsToInspector(owner), layerIsVisible(textLayer) {
                    add(target: textLayer, source: "CATextLayer.string", propertyName: FLEXReplicaTextPatchKey.layerString,
                        value: stringValue(textLayer.string))
                }
            }
            for child in layer.sublayers ?? [] {
                visitLayers(child)
            }
        }

        visit(root)
        visitLayers(root.layer)
        return result.sorted {
            if $0.source != $1.source { return $0.source.localizedCaseInsensitiveCompare($1.source) == .orderedAscending }
            return $0.value.localizedCaseInsensitiveCompare($1.value) == .orderedAscending
        }
    }

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
                 frame: NSCoder.string(for: view.frame),
                 isHidden: view.isHidden,
                 alpha: Double(view.alpha),
                 children: view.subviews.map(makeNode))
    }
}
#endif
