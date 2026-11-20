#if canImport(UIKit) && canImport(SwiftUI)
import SwiftUI
import UIKit
#if canImport(FLEXReplicaAutoOpen)
import FLEXReplicaAutoOpen
#endif

@MainActor
public enum FLEXReplicaMenuLauncher {
    /// Present the inspector panel in the foreground app after its UI scene is active.
    public static func showMenu() {
        let activeScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
        guard let window = activeScenes
            .flatMap(\.windows)
            .first(where: { $0.isKeyWindow }),
              let root = window.rootViewController else { return }

        let presenter = topViewController(from: root)
        guard !(presenter is UIHostingController<FLEXReplicaPanel>) else { return }

        let host = UIHostingController(rootView: FLEXReplicaPanel())
        host.modalPresentationStyle = .pageSheet
        host.isModalInPresentation = false
        presenter.present(host, animated: true)
    }

    private static func topViewController(from controller: UIViewController) -> UIViewController {
        if let navigation = controller as? UINavigationController,
           let visible = navigation.visibleViewController {
            return topViewController(from: visible)
        }
        if let tab = controller as? UITabBarController,
           let selected = tab.selectedViewController {
            return topViewController(from: selected)
        }
        if let presented = controller.presentedViewController {
            return topViewController(from: presented)
        }
        return controller
    }
}

/// C-callable entry point. Call after the host app has a foreground UIWindowScene.
@_cdecl("FLEXReplicaShowMenu")
public func FLEXReplicaShowMenu() {
#if canImport(FLEXReplicaAutoOpen)
    _ = FLEXReplicaAutoOpenEnsureLinked()
#endif
    Task { @MainActor in
        FLEXReplicaMenuLauncher.showMenu()
    }
}
#endif
