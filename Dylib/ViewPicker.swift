import UIKit
import SwiftUI
#if canImport(FLEXReplicaCore)
import FLEXReplicaCore
#endif

// MARK: - Localizar a view tocada no app hospedeiro

@MainActor
enum HostViewFinder {
    /// `point` está nas coordenadas da janela do overlay. Percorre as janelas do app (da mais alta para a
    /// mais baixa), ignorando o próprio overlay, e devolve a view mais profunda sob o ponto.
    static func view(at point: CGPoint, from overlayWindow: UIWindow) -> UIView? {
        guard let scene = overlayWindow.windowScene else { return nil }
        let inspector = ViewHierarchyInspector()
        let windows = scene.windows
            .filter { $0 !== overlayWindow && !$0.isHidden && $0.alpha > 0.01 }
            .sorted { $0.windowLevel > $1.windowLevel }
        for window in windows {
            let local = window.convert(point, from: overlayWindow)
            if let hit = inspector.view(at: local, in: window), hit !== window { return hit }
        }
        return nil
    }
}

// MARK: - Modelo da seleção

@MainActor
final class ViewSelection: ObservableObject {
    @Published private(set) var view: UIView
    @Published private(set) var snapshot: ObjectSnapshot
    private let inspector = ObjectInspector()
    private let onChange: (UIView) -> Void

    init(view: UIView, onChange: @escaping (UIView) -> Void) {
        self.view = view
        self.snapshot = ObjectInspector().snapshot(view)
        self.onChange = onChange
    }

    func select(_ newView: UIView) {
        view = newView
        snapshot = inspector.snapshot(newView)
        onChange(newView)       // o overlay move o realce para a nova view
    }
}

// MARK: - Tela de detalhes

private struct ViewRow: Identifiable {
    let view: UIView
    var id: ObjectIdentifier { ObjectIdentifier(view) }
}

@MainActor
struct ViewDetailSheet: View {
    @ObservedObject var selection: ViewSelection
    let onBrowseClass: (String) -> Void
    let onClose: () -> Void

    var body: some View {
        let target = selection.view
        let className = NSStringFromClass(type(of: target))
        NavigationStack {
            List {
                Section {
                    Text(className).font(.system(.subheadline, design: .monospaced)).bold()
                    row("Address", selection.snapshot.address)
                    row("Frame", NSCoder.string(for: target.frame))
                    row("Alpha / hidden", String(format: "%.2f / %@", Double(target.alpha), target.isHidden ? "yes" : "no"))
                    row("Background", target.backgroundColor.map { String(describing: $0) } ?? "nil")
                    row("Accessibility ID", target.accessibilityIdentifier ?? "nil")
                    row("View controller", owningController(of: target).map { NSStringFromClass(type(of: $0)) } ?? "none")
                    Button("Browse class methods") { onBrowseClass(className) }
                }

                let ancestors = ancestorRows(of: target)
                Section("Superview chain (\(ancestors.count))") {
                    ForEach(ancestors) { item in viewButton(item.view) }
                }

                let children = target.subviews.map(ViewRow.init)
                Section("Subviews (\(children.count))") {
                    ForEach(children.prefix(80)) { item in viewButton(item.view) }
                }

                Section("Properties (\(selection.snapshot.properties.count))") {
                    ForEach(selection.snapshot.properties.prefix(60)) { property in
                        row(property.name, property.valueDescription)
                    }
                }

                Section("Ivars (\(selection.snapshot.fields.count))") {
                    ForEach(selection.snapshot.fields.prefix(60)) { field in
                        row(field.name, field.valueDescription)
                    }
                }
            }
            .navigationTitle("View")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Close", action: onClose) } }
        }
    }

    private func viewButton(_ view: UIView) -> some View {
        Button { selection.select(view) } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(NSStringFromClass(type(of: view))).font(.system(.footnote, design: .monospaced))
                Text(NSCoder.string(for: view.frame)).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value).font(.system(.caption, design: .monospaced)).multilineTextAlignment(.trailing)
        }
    }

    private func ancestorRows(of view: UIView) -> [ViewRow] {
        var result: [ViewRow] = []
        var current = view.superview
        while let ancestor = current {
            result.append(ViewRow(view: ancestor))
            current = ancestor.superview
        }
        return result
    }

    private func owningController(of view: UIView) -> UIViewController? {
        var responder: UIResponder? = view
        while let current = responder {
            if let controller = current as? UIViewController { return controller }
            responder = current.next
        }
        return nil
    }
}
