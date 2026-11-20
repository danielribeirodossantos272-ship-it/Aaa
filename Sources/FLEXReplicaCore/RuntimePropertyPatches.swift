import Foundation
import Combine
#if canImport(FLEXReplicaRuntimeBridge)
import FLEXReplicaRuntimeBridge
#endif

public enum FLEXReplicaPropertyValueKind: String, Hashable, Sendable {
    case string
    case boolean
    case number

    public var label: String {
        switch self {
        case .string: return "String"
        case .boolean: return "Bool"
        case .number: return "Number"
        }
    }
}

public enum FLEXReplicaPatchValue: Hashable, Sendable, Codable {
    case null
    case string(String)
    case boolean(Bool)
    case number(Double)

    public var displayValue: String {
        switch self {
        case .null: return "nil"
        case .string(let value): return value
        case .boolean(let value): return value ? "true" : "false"
        case .number(let value): return String(value)
        }
    }

    fileprivate var foundationValue: AnyObject? {
        switch self {
        case .null: return nil
        case .string(let value): return value as NSString
        case .boolean(let value): return NSNumber(value: value)
        case .number(let value): return NSNumber(value: value)
        }
    }

    public static func parse(_ rawValue: String, as kind: FLEXReplicaPropertyValueKind) -> FLEXReplicaPatchValue? {
        switch kind {
        case .string:
            return .string(rawValue)
        case .boolean:
            switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "1", "yes": return .boolean(true)
            case "false", "0", "no": return .boolean(false)
            default: return nil
            }
        case .number:
            guard let value = Double(rawValue.trimmingCharacters(in: .whitespacesAndNewlines)), value.isFinite else {
                return nil
            }
            return .number(value)
        }
    }
}

@MainActor
public final class FLEXReplicaPropertyPatch: ObservableObject, Identifiable {
    public let id: UUID
    public let name: String
    public var title: String { name }
    public let className: String
    @Published public fileprivate(set) var objectAddress: String
    public let propertyName: String
    @Published public fileprivate(set) var originalValue: FLEXReplicaPatchValue
    public let replacementValue: FLEXReplicaPatchValue
    @Published public fileprivate(set) var isActive: Bool
    @Published public fileprivate(set) var lastError: String?
    fileprivate weak var targetObject: AnyObject?

    public var isBound: Bool { targetObject != nil }

    fileprivate init(id: UUID = UUID(),
                     name: String,
                     className: String,
                     objectAddress: String,
                     propertyName: String,
                     originalValue: FLEXReplicaPatchValue,
                     replacementValue: FLEXReplicaPatchValue,
                     targetObject: AnyObject?,
                     lastError: String? = nil) {
        self.id = id
        self.name = name
        self.className = className
        self.objectAddress = objectAddress
        self.propertyName = propertyName
        self.originalValue = originalValue
        self.replacementValue = replacementValue
        self.targetObject = targetObject
        self.isActive = false
        self.lastError = lastError
    }
}

@MainActor
public final class FLEXReplicaPatchStore: ObservableObject {
    public static let shared = FLEXReplicaPatchStore()

    @Published public private(set) var patches: [FLEXReplicaPropertyPatch] = []

    private struct SavedPatch: Codable {
        let id: UUID
        let name: String
        let className: String
        let propertyName: String
        var originalValue: FLEXReplicaPatchValue
        let replacementValue: FLEXReplicaPatchValue
    }

    private let defaults: UserDefaults
    private let storageKey: String

    public init(defaults: UserDefaults = .standard,
                storageKey: String = "FLEXReplica.savedPropertyPatches.v1") {
        self.defaults = defaults
        self.storageKey = storageKey
        if let data = defaults.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([SavedPatch].self, from: data) {
            self.patches = saved.map { item in
                FLEXReplicaPropertyPatch(id: item.id,
                                         name: item.name,
                                         className: item.className,
                                         objectAddress: "not linked",
                                         propertyName: item.propertyName,
                                         originalValue: item.originalValue,
                                         replacementValue: item.replacementValue,
                                         targetObject: nil,
                                         lastError: "Patch salvo. Selecione um objeto desta classe e vincule-o antes de ativar.")
            }
        }
    }

    /// Creates and saves an inactive, named override for one selected object property.
    @discardableResult
    public func createPatch(on object: AnyObject,
                            snapshot: ObjectSnapshot,
                            property: InspectedProperty,
                            name: String,
                            replacementValue: FLEXReplicaPatchValue) -> String? {
        guard property.isWritable, let kind = property.editableKind else {
            return "Esta propriedade não é editável por este inspetor."
        }
        guard replacementValue.matches(kind) else {
            return "O valor não corresponde ao tipo \(kind.label)."
        }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            return "Digite um nome para salvar o patch."
        }
        guard let originalValue = readValue(from: object, propertyName: property.name, kind: kind) else {
            return "Não foi possível ler a propriedade com segurança."
        }
        guard originalValue != replacementValue else {
            return "O valor novo é igual ao valor atual."
        }

        let patch = FLEXReplicaPropertyPatch(name: cleanName,
                                             className: snapshot.className,
                                             objectAddress: snapshot.address,
                                             propertyName: property.name,
                                             originalValue: originalValue,
                                             replacementValue: replacementValue,
                                             targetObject: object)
        patches.insert(patch, at: 0)
        persist()
        return nil
    }

    /// Rebinds a saved definition to the currently selected live object of the same class.
    @discardableResult
    public func bind(_ patch: FLEXReplicaPropertyPatch,
                     to object: AnyObject,
                     snapshot: ObjectSnapshot) -> String? {
        guard patches.contains(where: { $0.id == patch.id }) else {
            return "Este patch não está mais na lista."
        }
        guard !patch.isActive else {
            return "Desative o patch antes de vinculá-lo a outro objeto."
        }
        guard snapshot.className == patch.className else {
            return "Este patch foi salvo para \(patch.className), mas o objeto selecionado é \(snapshot.className)."
        }
        guard let property = snapshot.properties.first(where: { $0.name == patch.propertyName }),
              property.isWritable,
              property.editableKind == patch.replacementValue.kind else {
            return "O objeto selecionado não tem uma propriedade compatível chamada \(patch.propertyName)."
        }
        guard let currentValue = readValue(from: object, propertyName: patch.propertyName,
                                           kind: patch.replacementValue.kind) else {
            return "Não foi possível ler a propriedade do objeto selecionado."
        }
        guard currentValue != patch.replacementValue else {
            return "A propriedade já contém o valor deste patch."
        }
        patch.originalValue = currentValue
        patch.objectAddress = snapshot.address
        patch.targetObject = object
        patch.lastError = nil
        persist()
        return nil
    }

    /// Applies or restores a patch. State changes only after the setter succeeds.
    @discardableResult
    public func setActive(_ isActive: Bool, for patch: FLEXReplicaPropertyPatch) -> String? {
        guard patches.contains(where: { $0.id == patch.id }) else {
            return "Este patch não está mais na lista."
        }
        guard patch.isActive != isActive else { return nil }
        guard let target = patch.targetObject else {
            patch.lastError = "Selecione um objeto compatível e vincule este patch antes de ativá-lo."
            return patch.lastError
        }
        if isActive,
           let conflicting = patches.first(where: {
               $0.id != patch.id && $0.isActive && $0.propertyName == patch.propertyName &&
               ($0.targetObject.map { $0 === target } ?? false)
           }) {
            patch.lastError = "Desative primeiro o patch \(conflicting.name) para esta propriedade."
            return patch.lastError
        }
        guard let currentValue = readValue(from: target, propertyName: patch.propertyName,
                                           kind: patch.replacementValue.kind) else {
            patch.lastError = "Não foi possível ler o valor atual com segurança."
            return patch.lastError
        }
        let value: FLEXReplicaPatchValue
        if isActive {
            guard currentValue != patch.replacementValue else {
                patch.lastError = "A propriedade já tem o valor do patch."
                return patch.lastError
            }
            patch.originalValue = currentValue
            value = patch.replacementValue
        } else {
            guard currentValue == patch.replacementValue else {
                patch.isActive = false
                patch.lastError = "O valor mudou externamente; foi preservado ao desativar."
                persist()
                return nil
            }
            value = patch.originalValue
        }
        guard writeValue(value, to: target, propertyName: patch.propertyName) else {
            patch.lastError = isActive ? "Não foi possível ativar o patch." : "Não foi possível restaurar o valor original."
            return patch.lastError
        }
        patch.isActive = isActive
        patch.lastError = nil
        persist()
        return nil
    }

    /// Removes a saved patch. An active override is restored before its definition is deleted.
    @discardableResult
    public func remove(_ patch: FLEXReplicaPropertyPatch) -> String? {
        if patch.isActive {
            if patch.targetObject == nil {
                patch.isActive = false
            } else if let error = setActive(false, for: patch) {
                return error
            }
        }
        patches.removeAll { $0.id == patch.id }
        persist()
        return nil
    }

    public func refreshAvailability() {
        var didChange = false
        for patch in patches where patch.targetObject == nil {
            if patch.isActive {
                patch.isActive = false
                didChange = true
            }
            if patch.lastError == nil {
                patch.lastError = "Patch salvo, mas sem objeto vinculado. Selecione o objeto e vincule-o para usar."
            }
        }
        if didChange { persist() }
    }

    private func persist() {
        let saved = patches.map {
            SavedPatch(id: $0.id,
                       name: $0.name,
                       className: $0.className,
                       propertyName: $0.propertyName,
                       originalValue: $0.originalValue,
                       replacementValue: $0.replacementValue)
        }
        guard let data = try? JSONEncoder().encode(saved) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private func readValue(from object: AnyObject,
                           propertyName: String,
                           kind: FLEXReplicaPropertyValueKind) -> FLEXReplicaPatchValue? {
        #if canImport(FLEXReplicaRuntimeBridge)
        var rawValue: AnyObject?
        guard FLEXReplicaTryGetObjectValue(object, propertyName, &rawValue) else { return nil }
        #else
        guard let nsObject = object as? NSObject else { return nil }
        let rawValue = nsObject.value(forKey: propertyName) as AnyObject?
        #endif

        guard let rawValue else { return .null }
        switch kind {
        case .string:
            guard let value = rawValue as? String else { return nil }
            return .string(value)
        case .boolean:
            guard let value = rawValue as? NSNumber else { return nil }
            return .boolean(value.boolValue)
        case .number:
            guard let value = rawValue as? NSNumber else { return nil }
            return .number(value.doubleValue)
        }
    }

    private func writeValue(_ value: FLEXReplicaPatchValue,
                            to object: AnyObject,
                            propertyName: String) -> Bool {
        #if canImport(FLEXReplicaRuntimeBridge)
        return FLEXReplicaTrySetObjectValue(object, propertyName, value.foundationValue)
        #else
        guard let nsObject = object as? NSObject else { return false }
        nsObject.setValue(value.foundationValue, forKey: propertyName)
        return true
        #endif
    }
}

private extension FLEXReplicaPatchValue {
    var kind: FLEXReplicaPropertyValueKind {
        switch self {
        case .null: return .string
        case .string: return .string
        case .boolean: return .boolean
        case .number: return .number
        }
    }

    func matches(_ kind: FLEXReplicaPropertyValueKind) -> Bool {
        switch (self, kind) {
        case (.string, .string), (.boolean, .boolean), (.number, .number): return true
        default: return false
        }
    }
}
