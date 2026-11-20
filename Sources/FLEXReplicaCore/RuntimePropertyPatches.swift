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

public enum FLEXReplicaPatchValue: Hashable, Sendable {
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
    public let title: String
    public let className: String
    public let objectAddress: String
    public let propertyName: String
    @Published public fileprivate(set) var originalValue: FLEXReplicaPatchValue
    public let replacementValue: FLEXReplicaPatchValue
    @Published public fileprivate(set) var isActive: Bool
    @Published public fileprivate(set) var lastError: String?
    fileprivate weak var targetObject: AnyObject?

    fileprivate init(className: String,
                     objectAddress: String,
                     propertyName: String,
                     originalValue: FLEXReplicaPatchValue,
                     replacementValue: FLEXReplicaPatchValue,
                     targetObject: AnyObject) {
        self.id = UUID()
        self.className = className
        self.objectAddress = objectAddress
        self.propertyName = propertyName
        self.title = "\(className).\(propertyName)"
        self.originalValue = originalValue
        self.replacementValue = replacementValue
        self.targetObject = targetObject
        self.isActive = false
        self.lastError = nil
    }
}

@MainActor
public final class FLEXReplicaPatchStore: ObservableObject {
    public static let shared = FLEXReplicaPatchStore()

    @Published public private(set) var patches: [FLEXReplicaPropertyPatch] = []

    public init() {}

    /// Creates an inactive reversible override for one selected object property.
    @discardableResult
    public func createPatch(on object: AnyObject,
                            snapshot: ObjectSnapshot,
                            property: InspectedProperty,
                            replacementValue: FLEXReplicaPatchValue) -> String? {
        guard property.isWritable, let kind = property.editableKind else {
            return "Esta propriedade não é editável por este inspetor."
        }
        guard replacementValue.matches(kind) else {
            return "O valor não corresponde ao tipo \(kind.label)."
        }
        if patches.contains(where: {
            $0.objectAddress == snapshot.address && $0.propertyName == property.name && $0.targetObject === object
        }) {
            return "Já existe um patch para essa propriedade deste objeto."
        }
        guard let originalValue = readValue(from: object, propertyName: property.name, kind: kind) else {
            return "Não foi possível ler a propriedade com segurança."
        }
        guard originalValue != replacementValue else {
            return "O valor novo é igual ao valor atual."
        }

        let patch = FLEXReplicaPropertyPatch(className: snapshot.className,
                                             objectAddress: snapshot.address,
                                             propertyName: property.name,
                                             originalValue: originalValue,
                                             replacementValue: replacementValue,
                                             targetObject: object)
        patches.insert(patch, at: 0)
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
            patch.lastError = "O objeto selecionado não está mais disponível."
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
        return nil
    }

    /// Removes a patch. An active override must be restored successfully first.
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
        return nil
    }

    public func refreshAvailability() {
        for patch in patches where patch.targetObject == nil {
            patch.lastError = "Objeto indisponível; o patch não pode ser reaplicado."
        }
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
