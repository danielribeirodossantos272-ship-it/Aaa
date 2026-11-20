import Foundation
#if canImport(ObjectiveC)
import ObjectiveC.runtime
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
        #if canImport(ObjectiveC)
        var count: UInt32 = 0
        guard let list = objc_copyClassList(&count) else { return [] }
        defer { free(UnsafeMutableRawPointer(list)) }
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return (0..<Int(count)).compactMap { index in
            let cls: AnyClass = list[index]
            let name = NSStringFromClass(cls)
            guard needle.isEmpty || name.lowercased().contains(needle) else { return nil }
            let superclass = class_getSuperclass(cls).map { NSStringFromClass($0) }
            return RuntimeClassInfo(id: name, name: name, superclass: superclass,
                                    methods: methodInfos(for: cls, classMethods: false),
                                    properties: propertyInfos(for: cls))
        }.sorted { $0.name < $1.name }
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
            return RuntimeMethodInfo(id: "\(className)::\(NSStringFromSelector(selector))",
                                     selector: NSStringFromSelector(selector),
                                     typeEncoding: method_getTypeEncoding(method).map { String(cString: $0) } ?? "",
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
                    let attributes = property_getAttributes(property).map { String(cString: $0) } ?? ""
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
