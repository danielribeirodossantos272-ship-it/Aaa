import SwiftUI
#if canImport(FLEXReplicaCore)
import FLEXReplicaCore
#endif

/// Método escolhido no painel para virar patch.
struct PatchDraft: Identifiable {
    let className: String
    let method: RuntimeMethodInfo
    var id: String { "\(className)::\(method.isClassMethod)::\(method.selector)" }
}

@MainActor
struct CreatePatchSheet: View {
    let draft: PatchDraft
    @ObservedObject var manager: PatchManager
    @Environment(\.dismiss) private var dismiss
    @State private var value = ""
    @State private var errorText: String?

    private var kind: PatchReturnKind {
        manager.returnKind(className: draft.className, selector: draft.method.selector,
                           isClassMethod: draft.method.isClassMethod) ?? .unsupported
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Method") {
                    Text("\(draft.method.isClassMethod ? "+" : "-")[\(draft.className) \(draft.method.selector)]")
                        .font(.system(.footnote, design: .monospaced))
                    Text("Returns: \(kind.displayName)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                switch kind {
                case .void:
                    Section { Text("void method: the patch turns it into a no-op.").font(.footnote) }
                case .unsupported:
                    Section { Text("This return type (struct/pointer) is not supported.").foregroundStyle(.red) }
                default:
                    Section("Return value") {
                        TextField(kind.inputHint, text: $value)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }
                if let errorText {
                    Section { Text(errorText).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Create patch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create & enable") { create() }.disabled(kind == .unsupported)
                }
            }
        }
    }

    private func create() {
        do {
            try manager.createPatch(className: draft.className, selector: draft.method.selector,
                                    isClassMethod: draft.method.isClassMethod,
                                    returnValue: kind == .void ? nil : value)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

@MainActor
struct PatchListView: View {
    @ObservedObject var manager: PatchManager
    @Environment(\.dismiss) private var dismiss
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            List {
                if manager.patches.isEmpty {
                    Text("No patches yet. Tap “Patch” next to a method.").foregroundStyle(.secondary)
                }
                ForEach(manager.patches) { patch in
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle(isOn: binding(for: patch)) {
                            Text(patch.title).font(.system(.footnote, design: .monospaced))
                        }
                        Text("returns: \(patch.returnValue ?? "void / nil")")
                            .font(.caption).foregroundStyle(.secondary)
                        if patch.isEnabled && !manager.isApplied(patch.id) {
                            Text("Enabled but not applied (class not loaded yet?)")
                                .font(.caption).foregroundStyle(.orange)
                        }
                    }
                }
                .onDelete { offsets in
                    let ids = offsets.map { manager.patches[$0].id }
                    ids.forEach { manager.remove(id: $0) }
                }
            }
            .navigationTitle("Patches")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .alert("Patch error", isPresented: Binding(get: { errorText != nil },
                                                       set: { if !$0 { errorText = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorText ?? "")
            }
        }
    }

    private func binding(for patch: MethodPatch) -> Binding<Bool> {
        Binding(
            get: { manager.patches.first { $0.id == patch.id }?.isEnabled ?? false },
            set: { newValue in
                do { try manager.setEnabled(newValue, for: patch.id) }
                catch { errorText = error.localizedDescription }
            }
        )
    }
}
