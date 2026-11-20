import SwiftUI
#if canImport(FLEXReplicaCore)
import FLEXReplicaCore
#endif

@main
@MainActor
struct FLEXReplicaDemoApp: App {
    init() {
        // Reaplica os patches que ficaram habilitados na última execução.
        PatchManager.shared.applyEnabledPatches()
    }

    var body: some Scene {
        WindowGroup {
            FLEXReplicaPanel()
        }
    }
}
