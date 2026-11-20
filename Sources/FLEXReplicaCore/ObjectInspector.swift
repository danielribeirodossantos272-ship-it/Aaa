import Foundation
#if canImport(ObjectiveC)
import ObjectiveC.runtime
#endif
#if canImport(FLEXReplicaRuntimeBridge)
import FLEXReplicaRuntimeBridge
#endif

public struct InspectedField: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let typeEncoding: String
    public let valueDescription: String
}

public struct InspectedProperty: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let attributes: String
    public let valueDescription: String
    public let isWritable: Bool
    public let editableKind: FLEXReplicaPropertyValueKind?
}

public struct ObjectSnapshot: Sendable {
    public let className: String
    public let address: String
    public let fields: [InspectedField]
    public let properties: [InspectedProperty]
}

public final class ObjectInspector {
    public init() {}

    public func snapshot(_ object: AnyObject) -> ObjectSnapshot {
        #if canImport(ObjectiveC)
        let cls: AnyClass = object_getClass(object) ?? NSObject.self
        let fields = collectFields(object: object, class: cls)
        let properties = collectProperties(object: object, class: cls, fields: fields)
        let ptr = Unmanaged.passUnretained(object).toOpaque()
        return ObjectSnapshot(className: NSStringFromClass(cls),
                              address: String(describing: ptr),
                              fields: fields,
                              properties: properties)
        #else
        return ObjectSnapshot(className: String(describing: type(of: object)),
                              address: "unavailable", fields: [], properties: [])
        #endif
    }

    #if canImport(ObjectiveC)
    private func collectFields(object: AnyObject, class cls: AnyClass) -> [InspectedField] {
        var result: [InspectedField] = []
        var current: AnyClass? = cls
        var seen = Set<String>()
        while let type = current {
            var count: UInt32 = 0
            if let ivars = class_copyIvarList(type, &count) {
                for index in 0..<Int(count) {
                    let ivar = ivars[index]
                    guard let namePointer = ivar_getName(ivar),
                          let encodingPointer = ivar_getTypeEncoding(ivar) else { continue }
                    let name = String(cString: namePointer)
                    guard seen.insert(name).inserted else { continue }
                    let encoding = String(cString: encodingPointer)
                    result.append(InspectedField(id: name, name: name, typeEncoding: encoding,
                                                 valueDescription: safeIvarDescription(object: object, ivar: ivar, encoding: encoding)))
                }
                free(ivars)
            }
            current = class_getSuperclass(type)
        }
        return result.sorted { $0.name < $1.name }
    }

    private func collectProperties(object: AnyObject, class cls: AnyClass, fields: [InspectedField]) -> [InspectedProperty] {
        var result: [InspectedProperty] = []
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
                    let writable = !attributes.split(separator: ",").contains("R")
                    let kind = writable ? editableKind(from: attributes) : nil
                    let candidates = ["_\(name)", name]
                    let fieldValue = fields.first { candidates.contains($0.name) }?.valueDescription ?? "<accessor not read>"
                    let valueDescription = safePropertyDescription(object: object, name: name) ?? fieldValue
                    result.append(InspectedProperty(id: "\(NSStringFromClass(type))::\(name)",
                                                     name: name,
                                                     attributes: attributes,
                                                     valueDescription: valueDescription,
                                                     isWritable: writable && kind != nil,
                                                     editableKind: kind))
                }
                free(properties)
            }
            current = class_getSuperclass(type)
        }
        return result.sorted { $0.name < $1.name }
    }

    private func editableKind(from attributes: String) -> FLEXReplicaPropertyValueKind? {
        guard let typeAttribute = attributes.split(separator: ",").first,
              typeAttribute.first == "T" else { return nil }
        let encoding = String(typeAttribute.dropFirst())
        if encoding == "@\"NSString\"" || encoding == "@\"NSMutableString\"" {
            return .string
        }
        if encoding == "@\"NSNumber\"" {
            return .number
        }
        if encoding == "B" {
            return .boolean
        }
        if ["c", "C", "s", "S", "i", "I", "l", "L", "q", "Q", "f", "d"].contains(encoding) {
            return .number
        }
        return nil
    }

    private func safePropertyDescription(object: AnyObject, name: String) -> String? {
        #if canImport(FLEXReplicaRuntimeBridge)
        var value: AnyObject?
        guard FLEXReplicaTryGetObjectValue(object, name as NSString, &value) else { return nil }
        return value.map { String(describing: $0) } ?? "nil"
        #else
        return nil
        #endif
    }

    private func safeIvarDescription(object: AnyObject, ivar: Ivar, encoding: String) -> String {
        guard encoding.hasPrefix("@") || encoding.hasPrefix("#") || encoding.hasPrefix(":") else {
            return "<scalar ivar; encoding \(encoding)>"
        }
        guard let value = object_getIvar(object, ivar) else { return "nil" }
        return String(describing: value)
    }
    #endif
}
