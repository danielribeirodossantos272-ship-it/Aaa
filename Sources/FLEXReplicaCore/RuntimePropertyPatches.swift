import Foundation
import Combine
#if canImport(UIKit)
import UIKit
import QuartzCore
#endif
#if canImport(FLEXReplicaRuntimeBridge)
import FLEXReplicaRuntimeBridge
#endif

enum FLEXReplicaTextPatchKey {
    static let prefix = "__FLEXReplica."
    static let attributedText = "__FLEXReplica.text.attributedText"
    static let attributedPlaceholder = "__FLEXReplica.text.attributedPlaceholder"
    static let buttonConfigurationTitle = "__FLEXReplica.button.configuration.title"
    static let layerString = "__FLEXReplica.layer.string"
    static let buttonTitlePrefix = "__FLEXReplica.button.title."
    static let buttonAttributedTitlePrefix = "__FLEXReplica.button.attributedTitle."
    static let segmentTitlePrefix = "__FLEXReplica.segment.title."

    static func buttonTitle(_ state: UInt) -> String { buttonTitlePrefix + String(state) }
    static func buttonAttributedTitle(_ state: UInt) -> String { buttonAttributedTitlePrefix + String(state) }
    static func segmentTitle(_ index: Int) -> String { segmentTitlePrefix + String(index) }
}

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
#if canImport(UIKit)
    private enum RuntimeTextBackup {
        case attributed(NSAttributedString)
        case buttonConfiguration(UIButton.Configuration)
    }
    private var runtimeTextBackups: [UUID: RuntimeTextBackup] = [:]
#endif

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
        if !patch.propertyName.hasPrefix(FLEXReplicaTextPatchKey.prefix) {
            guard let property = snapshot.properties.first(where: { $0.name == patch.propertyName }),
                  property.isWritable,
                  property.editableKind == patch.replacementValue.kind else {
                return "O objeto selecionado não tem uma propriedade compatível chamada \(patch.propertyName)."
            }
        }
        guard let currentValue = readValue(from: object, propertyName: patch.propertyName,
                                           kind: patch.replacementValue.kind) else {
            return "Não foi possível ler a propriedade do objeto selecionado."
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
            if currentValue == patch.replacementValue {
                patch.originalValue = currentValue
#if canImport(UIKit)
                captureRuntimeTextBackup(for: patch, from: target)
#endif
                patch.isActive = true
                patch.lastError = nil
                persist()
                return nil
            }
            patch.originalValue = currentValue
            value = patch.replacementValue
        } else {
            guard currentValue == patch.replacementValue else {
                patch.isActive = false
                patch.lastError = "O valor mudou externamente; foi preservado ao desativar."
#if canImport(UIKit)
                runtimeTextBackups.removeValue(forKey: patch.id)
#endif
                persist()
                return nil
            }
            value = patch.originalValue
        }
        if isActive {
#if canImport(UIKit)
            captureRuntimeTextBackup(for: patch, from: target)
#endif
        }
        let didWrite: Bool
#if canImport(UIKit)
        if !isActive, let restored = restoreRuntimeTextBackup(for: patch, on: target) {
            didWrite = restored
        } else {
            didWrite = writeValue(value, to: target, propertyName: patch.propertyName)
        }
#else
        didWrite = writeValue(value, to: target, propertyName: patch.propertyName)
#endif
        guard didWrite else {
#if canImport(UIKit)
            runtimeTextBackups.removeValue(forKey: patch.id)
#endif
            patch.lastError = isActive ? "Não foi possível ativar o patch." : "Não foi possível restaurar o valor original."
            return patch.lastError
        }
        patch.isActive = isActive
        patch.lastError = nil
#if canImport(UIKit)
        if !isActive { runtimeTextBackups.removeValue(forKey: patch.id) }
#endif
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
#if canImport(UIKit)
        if propertyName.hasPrefix(FLEXReplicaTextPatchKey.prefix) {
            guard let value = readRuntimeText(from: object, propertyName: propertyName) else { return nil }
            return .string(value)
        }
#endif
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
#if canImport(UIKit)
        if propertyName.hasPrefix(FLEXReplicaTextPatchKey.prefix) {
            guard case .string(let string) = value else { return false }
            return writeRuntimeText(string, to: object, propertyName: propertyName)
        }
#endif
        #if canImport(FLEXReplicaRuntimeBridge)
        return FLEXReplicaTrySetObjectValue(object, propertyName, value.foundationValue)
        #else
        guard let nsObject = object as? NSObject else { return false }
        nsObject.setValue(value.foundationValue, forKey: propertyName)
        return true
        #endif
    }

#if canImport(UIKit)
    private func readRuntimeText(from object: AnyObject, propertyName: String) -> String? {
        if propertyName == FLEXReplicaTextPatchKey.attributedText {
            return attributedText(of: object)?.string
        }
        if propertyName == FLEXReplicaTextPatchKey.attributedPlaceholder {
            return (object as? UITextField)?.attributedPlaceholder?.string
        }
        if propertyName == FLEXReplicaTextPatchKey.buttonConfigurationTitle {
            return (object as? UIButton)?.configuration?.title
        }
        if propertyName.hasPrefix(FLEXReplicaTextPatchKey.buttonTitlePrefix),
           let raw = UInt(String(propertyName.dropFirst(FLEXReplicaTextPatchKey.buttonTitlePrefix.count))),
           let button = object as? UIButton {
            return button.title(for: UIControl.State(rawValue: raw))
        }
        if propertyName.hasPrefix(FLEXReplicaTextPatchKey.buttonAttributedTitlePrefix),
           let raw = UInt(String(propertyName.dropFirst(FLEXReplicaTextPatchKey.buttonAttributedTitlePrefix.count))),
           let button = object as? UIButton {
            return button.attributedTitle(for: UIControl.State(rawValue: raw))?.string
        }
        if propertyName.hasPrefix(FLEXReplicaTextPatchKey.segmentTitlePrefix),
           let index = Int(String(propertyName.dropFirst(FLEXReplicaTextPatchKey.segmentTitlePrefix.count))),
           let segmented = object as? UISegmentedControl,
           index >= 0, index < segmented.numberOfSegments {
            return segmented.titleForSegment(at: index)
        }
        if propertyName == FLEXReplicaTextPatchKey.layerString,
           let layer = object as? CATextLayer {
            if let attributed = layer.string as? NSAttributedString { return attributed.string }
            if let string = layer.string as? NSString { return string as String }
            return layer.string as? String
        }
        return nil
    }

    private func writeRuntimeText(_ string: String, to object: AnyObject, propertyName: String) -> Bool {
        if propertyName == FLEXReplicaTextPatchKey.attributedText {
            guard let current = attributedText(of: object) else { return false }
            let replacement = styled(string, like: current)
            if let label = object as? UILabel { label.attributedText = replacement; return true }
            if let field = object as? UITextField { field.attributedText = replacement; return true }
            if let textView = object as? UITextView { textView.attributedText = replacement; return true }
            return false
        }
        if propertyName == FLEXReplicaTextPatchKey.attributedPlaceholder,
           let field = object as? UITextField,
           let current = field.attributedPlaceholder {
            field.attributedPlaceholder = styled(string, like: current)
            return true
        }
        if propertyName == FLEXReplicaTextPatchKey.buttonConfigurationTitle,
           let button = object as? UIButton,
           var configuration = button.configuration {
            configuration.title = string
            button.configuration = configuration
            return true
        }
        if propertyName.hasPrefix(FLEXReplicaTextPatchKey.buttonTitlePrefix),
           let raw = UInt(String(propertyName.dropFirst(FLEXReplicaTextPatchKey.buttonTitlePrefix.count))),
           let button = object as? UIButton {
            button.setTitle(string, for: UIControl.State(rawValue: raw))
            return true
        }
        if propertyName.hasPrefix(FLEXReplicaTextPatchKey.buttonAttributedTitlePrefix),
           let raw = UInt(String(propertyName.dropFirst(FLEXReplicaTextPatchKey.buttonAttributedTitlePrefix.count))),
           let button = object as? UIButton {
            let state = UIControl.State(rawValue: raw)
            let current = button.attributedTitle(for: state)
            button.setAttributedTitle(styled(string, like: current), for: state)
            return true
        }
        if propertyName.hasPrefix(FLEXReplicaTextPatchKey.segmentTitlePrefix),
           let index = Int(String(propertyName.dropFirst(FLEXReplicaTextPatchKey.segmentTitlePrefix.count))),
           let segmented = object as? UISegmentedControl,
           index >= 0, index < segmented.numberOfSegments {
            segmented.setTitle(string, forSegmentAt: index)
            return true
        }
        if propertyName == FLEXReplicaTextPatchKey.layerString,
           let layer = object as? CATextLayer {
            if let current = layer.string as? NSAttributedString {
                layer.string = styled(string, like: current)
            } else {
                layer.string = string as NSString
            }
            return true
        }
        return false
    }

    private func captureRuntimeTextBackup(for patch: FLEXReplicaPropertyPatch, from object: AnyObject) {
        let key = patch.propertyName
        if key == FLEXReplicaTextPatchKey.buttonConfigurationTitle,
           let configuration = (object as? UIButton)?.configuration {
            runtimeTextBackups[patch.id] = .buttonConfiguration(configuration)
            return
        }
        if let attributed = attributedText(for: object, propertyName: key) {
            runtimeTextBackups[patch.id] = .attributed(attributed)
        }
    }

    private func restoreRuntimeTextBackup(for patch: FLEXReplicaPropertyPatch, on object: AnyObject) -> Bool? {
        guard let backup = runtimeTextBackups[patch.id] else { return nil }
        switch backup {
        case .buttonConfiguration(let configuration):
            guard let button = object as? UIButton else { return false }
            button.configuration = configuration
            return true
        case .attributed(let attributed):
            let key = patch.propertyName
            if key == FLEXReplicaTextPatchKey.attributedText {
                return setAttributedText(attributed, on: object)
            }
            if key == FLEXReplicaTextPatchKey.attributedPlaceholder,
               let field = object as? UITextField {
                field.attributedPlaceholder = attributed
                return true
            }
            if key.hasPrefix(FLEXReplicaTextPatchKey.buttonAttributedTitlePrefix),
               let raw = UInt(String(key.dropFirst(FLEXReplicaTextPatchKey.buttonAttributedTitlePrefix.count))),
               let button = object as? UIButton {
                button.setAttributedTitle(attributed, for: UIControl.State(rawValue: raw))
                return true
            }
            if key == FLEXReplicaTextPatchKey.layerString, let layer = object as? CATextLayer {
                layer.string = attributed
                return true
            }
            return false
        }
    }

    private func attributedText(of object: AnyObject) -> NSAttributedString? {
        if let label = object as? UILabel { return label.attributedText }
        if let field = object as? UITextField { return field.attributedText }
        if let textView = object as? UITextView { return textView.attributedText }
        return nil
    }

    private func attributedText(for object: AnyObject, propertyName: String) -> NSAttributedString? {
        if propertyName == FLEXReplicaTextPatchKey.attributedText { return attributedText(of: object) }
        if propertyName == FLEXReplicaTextPatchKey.attributedPlaceholder {
            return (object as? UITextField)?.attributedPlaceholder
        }
        if propertyName.hasPrefix(FLEXReplicaTextPatchKey.buttonAttributedTitlePrefix),
           let raw = UInt(String(propertyName.dropFirst(FLEXReplicaTextPatchKey.buttonAttributedTitlePrefix.count))) {
            return (object as? UIButton)?.attributedTitle(for: UIControl.State(rawValue: raw))
        }
        if propertyName == FLEXReplicaTextPatchKey.layerString {
            return (object as? CATextLayer)?.string as? NSAttributedString
        }
        return nil
    }

    private func setAttributedText(_ value: NSAttributedString, on object: AnyObject) -> Bool {
        if let label = object as? UILabel { label.attributedText = value; return true }
        if let field = object as? UITextField { field.attributedText = value; return true }
        if let textView = object as? UITextView { textView.attributedText = value; return true }
        return false
    }

    private func styled(_ string: String, like original: NSAttributedString?) -> NSAttributedString {
        guard let original, original.length > 0 else { return NSAttributedString(string: string) }
        return NSAttributedString(string: string, attributes: original.attributes(at: 0, effectiveRange: nil))
    }
#endif
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
