import SwiftUI
#if canImport(FLEXReplicaCore)
import FLEXReplicaCore
#endif

@MainActor
public struct FLEXReplicaPanel: View {
    @StateObject private var session = InspectorSession()
    @State private var query = "UIView"
    @State private var opacity = InspectorPreferences().panelOpacity
    @State private var showClassMethods = false
    private let preferences = PreferencesStore()

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("FLEX Replica").font(.headline)
                Spacer()
                Text("Independent").font(.caption).foregroundStyle(.secondary)
            }

            HStack {
                TextField("Search classes", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { session.searchClasses(query) }
                Button("Search") { session.searchClasses(query) }
                    .buttonStyle(.borderedProminent)
            }

            if !session.matchingClasses.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 6) {
                        ForEach(session.matchingClasses.prefix(60)) { info in
                            Button(info.name) { session.selectClass(info.name) }
                                .buttonStyle(.bordered)
                                .font(.caption)
                        }
                    }
                }
                .frame(height: 34)
            }

            Toggle("Class methods", isOn: $showClassMethods)
                .font(.caption)

            if let info = session.selectedClass {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(info.name).font(.subheadline).bold()
                        Text("Superclass: \(info.superclass ?? "none")")
                            .font(.caption).foregroundStyle(.secondary)

                        Text("Properties (\(info.properties.count))").font(.subheadline.bold())
                        ForEach(info.properties.prefix(80)) { property in
                            VStack(alignment: .leading) {
                                Text(property.name).font(.system(.body, design: .monospaced))
                                Text(property.attributes).font(.caption2).foregroundStyle(.secondary)
                            }
                        }

                        let methods = showClassMethods ? session.methods(for: info.name, classMethods: true) : info.methods
                        Text("Methods (\(methods.count))").font(.subheadline.bold())
                        ForEach(methods.prefix(120)) { method in
                            VStack(alignment: .leading) {
                                Text(method.selector).font(.system(.body, design: .monospaced))
                                Text(method.typeEncoding).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(minHeight: 220)
            } else {
                Text("Search for a class to inspect its selectors and properties.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Text("Opacity")
                Slider(value: $opacity, in: 0.5...1)
            }
        }
        .padding(14)
        .frame(minWidth: 320, minHeight: 420)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 12)
        .opacity(opacity)
        .onAppear {
            opacity = preferences.value.panelOpacity
            session.searchClasses(query)
        }
        .onChange(of: opacity) { newValue in
            var value = preferences.value
            value.panelOpacity = newValue
            preferences.value = value
        }
    }
}
