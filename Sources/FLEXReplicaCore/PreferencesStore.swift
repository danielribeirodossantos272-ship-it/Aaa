import Foundation

public struct InspectorPreferences: Codable, Equatable, Sendable {
    public var showsPrivateClasses: Bool
    public var showsAddresses: Bool
    public var panelOpacity: Double
    public var accentColorHex: String

    public init(showsPrivateClasses: Bool = false, showsAddresses: Bool = false,
                panelOpacity: Double = 0.96, accentColorHex: String = "#22C55E") {
        self.showsPrivateClasses = showsPrivateClasses
        self.showsAddresses = showsAddresses
        self.panelOpacity = panelOpacity
        self.accentColorHex = accentColorHex
    }
}

public final class PreferencesStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "flexReplica.preferences.v1"
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public var value: InspectorPreferences {
        get {
            guard let data = defaults.data(forKey: key),
                  let decoded = try? JSONDecoder().decode(InspectorPreferences.self, from: data) else { return InspectorPreferences() }
            return decoded
        }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: key) }
    }
}
