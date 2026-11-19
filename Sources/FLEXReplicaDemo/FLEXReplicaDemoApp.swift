import SwiftUI
#if canImport(FLEXReplicaCore)
import FLEXReplicaCore
#endif

@main
struct FLEXReplicaDemoApp: App {
    var body: some Scene {
        WindowGroup {
            FLEXReplicaPanel()
        }
    }
}
