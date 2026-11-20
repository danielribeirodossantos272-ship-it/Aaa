import Foundation
#if canImport(ObjectiveC)
import ObjectiveC.runtime
#endif
#if canImport(FLEXReplicaRuntimeBridge)
import FLEXReplicaRuntimeBridge
#endif

public struct RuntimeMethodInfo: Identifiable, Hashable, Sendable {
    public let id: String
    public let selector: String
    public let typeEncoding: String
    public let isClassMethod: Bool
}

public struct RuntimePropertyInfo: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let attributes: String
}

public struct RuntimeClassInfo: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let superclass: String?
    public let methods: [RuntimeMethodInfo]
    public let properties: [RuntimePropertyInfo]
}

public final class RuntimeBrowser {
    public init() {}

    public func classes(matching query: String = "") -> [RuntimeClassInfo] {
        classNames(matching: query)
            .compactMap { info(for: $0) }
            .sorted { $0.name < $1.name }
    }

    public func classNames(matching query: String = "") -> [String] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        #if canImport(ObjectiveC) && canImport(FLEXReplicaRuntimeBridge)
        return FLEXReplicaCopyRuntimeClassNames()
            .filter { needle.isEmpty || $0.lowercased().contains(needle) }
        #elseif canImport(ObjectiveC)
        var count: UInt32 = 0
        guard let list = objc_copyClassList(&count) else { return [] }
        defer { free(UnsafeMutableRawPointer(list)) }
        return (0..<Int(count))
            .map { NSStringFromClass(list[$0]) }
            .filter { needle.isEmpty || $0.lowercased().contains(needle) }
            .sorted()
        #else
        return []
        #endif
    }

    public func info(for className: String) -> RuntimeClassInfo? {
        #if canImport(ObjectiveC)
        guard let cls = NSClassFromString(className) else { return nil }
        return makeInfo(for: cls)
        #else
        return nil
        #endif
    }

    public func methods(for className: String, classMethods: Bool = false) -> [RuntimeMethodInfo] {
        #if canImport(ObjectiveC)
        guard let cls = NSClassFromString(className) else { return [] }
        return methodInfos(for: cls, classMethods: classMethods)
        #else
        return []
        #endif
    }

    #if canImport(ObjectiveC)
    private func makeInfo(for cls: AnyClass) -> RuntimeClassInfo {
        let name = NSStringFromClass(cls)
        return RuntimeClassInfo(id: name, name: name,
                                superclass: class_getSuperclass(cls).map { NSStringFromClass($0) },
                                methods: methodInfos(for: cls, classMethods: false),
                                properties: propertyInfos(for: cls))
    }

    private func methodInfos(for cls: AnyClass, classMethods: Bool) -> [RuntimeMethodInfo] {
        let target: AnyClass = classMethods ? object_getClass(cls)! : cls
        var count: UInt32 = 0
        guard let methods = class_copyMethodList(target, &count) else { return [] }
        defer { free(methods) }
        let className = String(cString: class_getName(cls))
        return (0..<Int(count)).map { index in
            let method = methods[index]
            let selector = method_getName(method)
            let encoding = method_getTypeEncoding(method).map { String(cString: $0) } ?? ""
            return RuntimeMethodInfo(id: "\(className)::\(NSStringFromSelector(selector))",
                                     selector: NSStringFromSelector(selector),
                                     typeEncoding: encoding,
                                     isClassMethod: classMethods)
        }.sorted { $0.selector < $1.selector }
    }

    private func propertyInfos(for cls: AnyClass) -> [RuntimePropertyInfo] {
        var result: [RuntimePropertyInfo] = []
        var current: AnyClass? = cls
        var seen = Set<String>()
        while let type = current {
            var count: UInt32 = 0
            if let properties = class_copyPropertyList(type, &count) {
                for index in 0..<Int(count) {
                    let property = properties[index]
                    let name = String(cString: property_getName(property))
                    guard seen.insert(name).inserted else { continue }
                    guard let attributesPointer = property_getAttributes(property) else { continue }
                    let attributes = String(cString: attributesPointer)
                    result.append(RuntimePropertyInfo(id: "\(NSStringFromClass(type))::\(name)", name: name, attributes: attributes))
                }
                free(properties)
            }
            current = class_getSuperclass(type)
        }
        return result.sorted { $0.name < $1.name }
    }
    #endif
}
