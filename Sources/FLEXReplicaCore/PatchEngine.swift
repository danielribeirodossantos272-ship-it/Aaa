import Foundation
import Combine
#if canImport(ObjectiveC)
import ObjectiveC.runtime
#endif

// MARK: - Model

/// Categoria do tipo de retorno de um método Objective-C que o patch sabe produzir.
public enum PatchReturnKind: Equatable, Sendable {
    case void, bool, int32, int64, float, double, object, cls, unsupported

    /// `encoding` é o type encoding do retorno (ex.: "B", "q", "@", "v", "{CGRect=...}").
    public init(encoding: String) {
        let stripped = encoding.drop { "rnNoORV".contains($0) }   // qualificadores (const, in, out, ...)
        guard let first = stripped.first else { self = .unsupported; return }
        switch first {
        case "v": self = .void
        case "B", "c": self = .bool                                // BOOL (bool no arm64, signed char no x86_64)
        case "i", "I", "s", "S", "C": self = .int32
        case "l", "L", "q", "Q": self = .int64
        case "f": self = .float
        case "d": self = .double
        case "@": self = .object
        case "#": self = .cls
        default: self = .unsupported                               // structs, ponteiros, unions...
        }
    }

    public var displayName: String {
        switch self {
        case .void: return "void"
        case .bool: return "BOOL"
        case .int32: return "int"
        case .int64: return "long / NSInteger"
        case .float: return "float"
        case .double: return "double / CGFloat"
        case .object: return "object"
        case .cls: return "Class"
        case .unsupported: return "unsupported"
        }
    }

    public var inputHint: String {
        switch self {
        case .bool: return "YES / NO"
        case .int32, .int64: return "42"
        case .float, .double: return "3.14"
        case .object: return "text, nil, @YES, @42"
        case .cls: return "ClassName"
        case .void, .unsupported: return ""
        }
    }
}

public enum PatchError: LocalizedError, Equatable {
    case classNotFound(String)
    case methodNotFound(String)
    case unsupportedReturnType(String)
    case unsupportedArgumentCount(Int)

    public var errorDescription: String? {
        switch self {
        case .classNotFound(let name): return "Class \(name) not found (not loaded yet?)."
        case .methodNotFound(let selector): return "Method \(selector) not found as an Objective-C method."
        case .unsupportedReturnType(let enc): return "Return type '\(enc)' is not supported (structs and pointers)."
        case .unsupportedArgumentCount(let count): return "Methods with \(count) explicit parameter(s) are not supported by this patch backend."
        }
    }
}

/// "Este método passa a retornar X." `returnValue` é o texto digitado:
/// `YES`, `42`, `3.14`, `hello`, `nil`, `@YES`, `@42` (NSNumber), nome de classe… Ignorado em métodos `void`.
public struct MethodPatch: Codable, Identifiable, Hashable, Sendable {
    public let className: String
    public let selector: String
    public let isClassMethod: Bool
    public var returnValue: String?
    public var isEnabled: Bool

    public init(className: String, selector: String, isClassMethod: Bool,
                returnValue: String?, isEnabled: Bool = true) {
        self.className = className
        self.selector = selector
        self.isClassMethod = isClassMethod
        self.returnValue = returnValue
        self.isEnabled = isEnabled
    }

    public var id: String { "\(isClassMethod ? "+" : "-")[\(className) \(selector)]" }
    public var title: String { id }
}

#if canImport(ObjectiveC)

// MARK: - IMP factory

enum PatchIMPFactory {
    /// Cria um IMP que devolve sempre o valor descrito por `text`. `nil` se o tipo não é suportado.
    static func makeIMP(kind: PatchReturnKind, text: String?) -> IMP? {
        let ns = NSString(string: text ?? "")
        switch kind {
        case .void:
            let block: @convention(block) (AnyObject) -> Void = { _ in }
            return imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
        case .bool:
            let value = ObjCBool(ns.boolValue)
            let block: @convention(block) (AnyObject) -> ObjCBool = { _ in value }
            return imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
        case .int32:
            let value = Int32(truncatingIfNeeded: ns.longLongValue)
            let block: @convention(block) (AnyObject) -> Int32 = { _ in value }
            return imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
        case .int64:
            let value = Int64(ns.longLongValue)
            let block: @convention(block) (AnyObject) -> Int64 = { _ in value }
            return imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
        case .float:
            let value = ns.floatValue
            let block: @convention(block) (AnyObject) -> Float = { _ in value }
            return imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
        case .double:
            let value = ns.doubleValue
            let block: @convention(block) (AnyObject) -> Double = { _ in value }
            return imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
        case .cls:
            let value: AnyClass? = text.flatMap { NSClassFromString($0) }
            let block: @convention(block) (AnyObject) -> AnyClass? = { _ in value }
            return imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
        case .object:
            let value: AnyObject? = objectValue(from: text)
            let block: @convention(block) (AnyObject) -> AnyObject? = { _ in value }
            return imp_implementationWithBlock(unsafeBitCast(block, to: AnyObject.self))
        case .unsupported:
            return nil
        }
    }

    private static func objectValue(from text: String?) -> AnyObject? {
        guard let text, text != "nil" else { return nil }
        if text.hasPrefix("@") {
            let rest = String(text.dropFirst())
            let number = NSString(string: rest)
            if rest.caseInsensitiveCompare("YES") == .orderedSame || rest.caseInsensitiveCompare("NO") == .orderedSame {
                return NSNumber(value: number.boolValue)
            }
            return rest.contains(".") ? NSNumber(value: number.doubleValue) : NSNumber(value: number.longLongValue)
        }
        return NSString(string: text)
    }
}

// MARK: - Manager

/// Cria, ativa, desativa, remove e persiste patches de método (como a aba de patches do FLEX 3).
@MainActor
public final class PatchManager: ObservableObject {
    public static let shared = PatchManager()

    @Published public private(set) var patches: [MethodPatch] = []

    private struct ActiveHook {
        let target: AnyClass      // classe (ou metaclasse, para métodos de classe)
        let selector: Selector
        let original: IMP         // IMP efetivo antes do patch (próprio ou herdado)
        let types: String
    }

    private let defaults: UserDefaults
    private let key = "flexReplica.patches.v1"
    private var hooks: [String: ActiveHook] = [:]

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([MethodPatch].self, from: data) {
            patches = decoded
        }
    }

    // MARK: Public API

    /// Tipo de retorno do método (para a UI mostrar dica ou desabilitar o botão).
    public func returnKind(className: String, selector: String, isClassMethod: Bool) -> PatchReturnKind? {
        guard let resolved = try? resolve(className: className, selector: selector, isClassMethod: isClassMethod) else { return nil }
        guard method_getNumberOfArguments(resolved.method) == 2 else { return .unsupported }
        return PatchReturnKind(encoding: returnEncoding(of: resolved.method))
    }

    /// Cria (substituindo um patch anterior do mesmo método) e já ativa.
    @discardableResult
    public func createPatch(className: String, selector: String, isClassMethod: Bool,
                            returnValue: String?) throws -> MethodPatch {
        let patch = MethodPatch(className: className, selector: selector,
                                isClassMethod: isClassMethod, returnValue: returnValue, isEnabled: true)
        revert(patch.id)                                   // evita capturar o IMP do patch antigo como "original"
        patches.removeAll { $0.id == patch.id }
        do { try install(patch) } catch { save(); throw error }
        patches.append(patch)
        save()
        return patch
    }

    public func setEnabled(_ enabled: Bool, for id: String) throws {
        guard let index = patches.firstIndex(where: { $0.id == id }) else { return }
        if enabled { try install(patches[index]) } else { revert(id) }
        patches[index].isEnabled = enabled
        save()
    }

    public func remove(id: String) {
        revert(id)
        patches.removeAll { $0.id == id }
        save()
    }

    public func isApplied(_ id: String) -> Bool { hooks[id] != nil }

    /// Reaplica os patches salvos como habilitados. Chame no início do app.
    /// Retorna os que falharam (ex.: classe de framework ainda não carregada) — chame de novo mais tarde.
    @discardableResult
    public func applyEnabledPatches() -> [String: PatchError] {
        var failures: [String: PatchError] = [:]
        for patch in patches where patch.isEnabled && hooks[patch.id] == nil {
            do { try install(patch) } catch { failures[patch.id] = error as? PatchError }
        }
        return failures
    }

    // MARK: Internals

    private func install(_ patch: MethodPatch) throws {
        guard hooks[patch.id] == nil else { return }
        let resolved = try resolve(className: patch.className, selector: patch.selector,
                                   isClassMethod: patch.isClassMethod)
        let argumentCount = method_getNumberOfArguments(resolved.method)
        guard argumentCount == 2 else {
            throw PatchError.unsupportedArgumentCount(argumentCount > 2 ? Int(argumentCount - 2) : 0)
        }
        let encoding = returnEncoding(of: resolved.method)
        guard let imp = PatchIMPFactory.makeIMP(kind: PatchReturnKind(encoding: encoding),
                                                text: patch.returnValue) else {
            throw PatchError.unsupportedReturnType(encoding)
        }
        let types = typeEncoding(of: resolved.method)
        hooks[patch.id] = ActiveHook(target: resolved.target, selector: resolved.selector,
                                     original: method_getImplementation(resolved.method), types: types)
        // class_replaceMethod adiciona o método na classe se ele era herdado,
        // sem tocar na superclasse (method_setImplementation alteraria a superclasse).
        _ = class_replaceMethod(resolved.target, resolved.selector, imp, types)
    }

    private func revert(_ id: String) {
        guard let hook = hooks.removeValue(forKey: id) else { return }
        _ = class_replaceMethod(hook.target, hook.selector, hook.original, hook.types)
        // O bloco do patch não é liberado (imp_removeBlock) de propósito:
        // outra thread pode estar executando o IMP agora. O vazamento é de poucos bytes.
    }

    private func resolve(className: String, selector: String,
                         isClassMethod: Bool) throws -> (target: AnyClass, selector: Selector, method: Method) {
        guard let cls = NSClassFromString(className) else { throw PatchError.classNotFound(className) }
        let target: AnyClass = isClassMethod ? (object_getClass(cls) ?? cls) : cls
        let sel = NSSelectorFromString(selector)
        guard let method = class_getInstanceMethod(target, sel) else { throw PatchError.methodNotFound(selector) }
        return (target, sel, method)
    }

    private func returnEncoding(of method: Method) -> String {
        let pointer: UnsafeMutablePointer<CChar>? = method_copyReturnType(method)
        guard let pointer else { return "" }
        defer { free(pointer) }
        return String(cString: pointer)
    }

    private func typeEncoding(of method: Method) -> String {
        let pointer: UnsafePointer<CChar>? = method_getTypeEncoding(method)
        guard let pointer else { return "" }
        return String(cString: pointer)
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(patches), forKey: key)
    }
}

#endif
