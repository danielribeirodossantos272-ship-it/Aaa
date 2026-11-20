import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

private enum FLEXReplicaSection: String, CaseIterable, Identifiable, Hashable {
    case views = "Views"
    case classes = "Classes"
    case object = "Object"
    case patches = "Patches"

    var id: String { rawValue }
}

@MainActor
public struct FLEXReplicaPanel: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var session = InspectorSession()
    @StateObject private var patchStore = FLEXReplicaPatchStore.shared
    @State private var query = "UIView"
    @State private var opacity = InspectorPreferences().panelOpacity
    @State private var showClassMethods = false
    @State private var selectedSection: FLEXReplicaSection = .views
    @State private var propertyDrafts: [String: String] = [:]
    private let preferences = PreferencesStore()

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Picker("Inspector section", selection: $selectedSection) {
                ForEach(FLEXReplicaSection.allCases) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)

            inspectorContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            HStack(spacing: 8) {
                Image(systemName: "circle.lefthalf.filled")
                    .foregroundStyle(.secondary)
                Text("Opacity")
                    .font(.caption)
                Slider(value: $opacity, in: 0.5...1)
            }
        }
        .padding(14)
        .frame(minWidth: 330, minHeight: 520)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 16)
        .opacity(opacity)
        .onAppear {
            opacity = preferences.value.panelOpacity
            session.searchClasses(query)
            patchStore.refreshAvailability()
            #if canImport(UIKit)
            refreshViewHierarchy()
            #endif
        }
        .onDisappear {
            #if canImport(UIKit)
            FLEXReplicaFloatingButtonController.shared.setHidden(false)
            #endif
        }
        .onChange(of: selectedSection) { section in
            if section == .object {
                session.refreshSelectedObject()
            } else if section == .patches {
                patchStore.refreshAvailability()
            }
        }
        .onChange(of: opacity) { newValue in
            var value = preferences.value
            value.panelOpacity = newValue
            preferences.value = value
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "viewfinder")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("FLEX Replica")
                    .font(.headline)
                Text("Runtime Inspector")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            #if canImport(UIKit)
            if selectedSection == .views {
                Button {
                    refreshViewHierarchy()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Refresh view hierarchy")
            }
            #endif
            Button("Close") { dismiss() }
                .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private var inspectorContent: some View {
        switch selectedSection {
        case .views:
            viewHierarchySection
        case .classes:
            classBrowserSection
        case .object:
            objectInspectorSection
        case .patches:
            patchesSection
        }
    }

    private var classBrowserSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                TextField("Search classes", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit { session.searchClasses(query) }
                Button {
                    session.searchClasses(query)
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Search classes")
            }

            Text("\(session.matchingClasses.count) matching classes")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !session.matchingClasses.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 6) {
                        ForEach(session.matchingClasses.prefix(100)) { info in
                            Button {
                                session.selectClass(info.name)
                            } label: {
                                Text(info.name)
                                    .font(.caption.monospaced())
                                    .lineLimit(1)
                            }
                            .buttonStyle(.bordered)
                            .tint(session.selectedClass?.name == info.name ? Color.accentColor : Color.gray)
                        }
                    }
                }
                .frame(height: 34)
            }

            Toggle("Show class methods", isOn: $showClassMethods)
                .font(.caption)

            if let info = session.selectedClass {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Group {
                            Text(info.name)
                                .font(.headline.monospaced())
                            Text("Superclass: \(info.superclass ?? "none")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        detailSection(title: "Properties (\(info.properties.count))") {
                            ForEach(info.properties.prefix(100)) { property in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(property.name).font(.caption.monospaced())
                                    Text(property.attributes)
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        let methods = showClassMethods
                            ? session.methods(for: info.name, classMethods: true)
                            : info.methods
                        detailSection(title: "Methods (\(methods.count))") {
                            ForEach(methods.prefix(150)) { method in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(method.selector).font(.caption.monospaced())
                                    Text(method.typeEncoding)
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else if session.matchingClasses.isEmpty {
                emptyState("No matching classes", symbol: "magnifyingglass")
            } else {
                emptyState("Select a class above to inspect details", symbol: "cursorarrow.click")
            }
        }
    }

    private var viewHierarchySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("View Hierarchy")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let root = session.rootViewTree {
                    Text("Root: \(root.className)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Divider()

            #if canImport(UIKit)
            if let root = session.rootViewTree, let window = foregroundWindow {
                ScrollView {
                    ViewNodeRow(node: root, root: window, session: session)
                        .padding(.vertical, 4)
                }
            } else {
                emptyState("View hierarchy unavailable", symbol: "rectangle.dashed")
            }
            #else
            emptyState("View inspection requires UIKit", symbol: "rectangle.dashed")
            #endif
        }
    }

    private var objectInspectorSection: some View {
        Group {
            if let object = session.selectedObject {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        detailSection(title: "Object") {
                            Text(object.className).font(.headline.monospaced())
                            Text("Address: \(object.address)")
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                        }

                        detailSection(title: "Properties (\(object.properties.count))") {
                            ForEach(object.properties) { property in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(property.name).font(.caption.monospaced())
                                    Text(property.valueDescription)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(property.attributes)
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.tertiary)
                                    if property.isWritable, let kind = property.editableKind {
                                        TextField("New \(kind.label) value", text: draftBinding(for: property))
                                            .textFieldStyle(.roundedBorder)
                                            .autocorrectionDisabled()
                                            .textInputAutocapitalization(.never)
                                        Button {
                                            let rawValue = propertyDrafts[property.id] ?? defaultDraft(for: property)
                                            if session.createPropertyPatch(for: property, rawValue: rawValue) {
                                                selectedSection = .patches
                                            }
                                        } label: {
                                            Label("Create Patch", systemImage: "plus.circle")
                                                .font(.caption.weight(.semibold))
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        if let error = session.patchActionError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        detailSection(title: "Ivars (\(object.fields.count))") {
                            ForEach(object.fields) { field in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(field.name).font(.caption.monospaced())
                                    Text("\(field.typeEncoding) · \(field.valueDescription)")
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else {
                emptyState("Select a view in the Views tab to inspect its object", symbol: "cube.transparent")
            }
        }
    }

    private var patchesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Temporary property overrides")
                .font(.subheadline.weight(.semibold))
            Text("Patches affect one selected object in this running app. They stay in memory and can be restored here.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let error = session.patchActionError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if patchStore.patches.isEmpty {
                emptyState("No patches yet — select an object and create one", symbol: "switch.2")
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(patchStore.patches) { patch in
                            PropertyPatchRow(patch: patch,
                                             onToggle: { isActive in
                                                 _ = session.setPatchActive(isActive, for: patch)
                                             },
                                             onRemove: {
                                                 _ = session.removePatch(patch)
                                             })
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func defaultDraft(for property: InspectedProperty) -> String {
        property.valueDescription == "nil" ? "" : property.valueDescription
    }

    private func draftBinding(for property: InspectedProperty) -> Binding<String> {
        Binding(
            get: { propertyDrafts[property.id] ?? defaultDraft(for: property) },
            set: { propertyDrafts[property.id] = $0 }
        )
    }

    private func detailSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            content()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func emptyState(_ title: String, symbol: String) -> some View {
        VStack(spacing: 8) {
            Spacer(minLength: 12)
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    #if canImport(UIKit)
    private var foregroundWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows)
            .first(where: { $0.isKeyWindow })
    }

    private func refreshViewHierarchy() {
        guard let window = foregroundWindow else { return }
        session.inspectViewTree(window)
    }
    #endif
}

#if canImport(UIKit)
@MainActor
private struct ViewNodeRow: View {
    let node: ViewNode
    let root: UIView
    @ObservedObject var session: InspectorSession
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(node.children) { child in
                ViewNodeRow(node: child, root: root, session: session)
                    .padding(.leading, 8)
            }
        } label: {
            Button {
                session.inspectView(withID: node.id, in: root)
            } label: {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: node.isHidden ? "eye.slash" : "rectangle")
                        .foregroundStyle(node.isHidden ? Color.gray : Color.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(node.className)
                            .font(.caption.monospaced())
                            .lineLimit(1)
                        Text("\(node.frame) · α \(node.alpha, format: .number.precision(.fractionLength(2)))")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .font(.caption)
    }
}

@MainActor
private struct PropertyPatchRow: View {
    @ObservedObject var patch: FLEXReplicaPropertyPatch
    let onToggle: (Bool) -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(patch.title)
                    .font(.caption.monospaced().weight(.semibold))
                    .lineLimit(2)
                Text("\(patch.originalValue.displayValue)  →  \(patch.replacementValue.displayValue)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                Text("\(patch.className) · \(patch.objectAddress)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                if let error = patch.lastError {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
            Spacer(minLength: 0)
            Toggle("Active", isOn: Binding(
                get: { patch.isActive },
                set: { onToggle($0) }
            ))
            .labelsHidden()
            Button(role: .destructive, action: onRemove) {
                Image(systemName: "trash")
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Remove patch")
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
#endif
