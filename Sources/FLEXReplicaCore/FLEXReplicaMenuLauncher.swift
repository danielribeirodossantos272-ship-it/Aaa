#if canImport(UIKit) && canImport(SwiftUI)
import SwiftUI
import UIKit
#if canImport(FLEXReplicaAutoOpen)
import FLEXReplicaAutoOpen
#endif

@MainActor
public enum FLEXReplicaMenuLauncher {
    /// Presents the inspector after the host app has an active foreground scene.
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
        FLEXReplicaFloatingButtonController.shared.setHidden(true)
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

@MainActor
public final class FLEXReplicaFloatingButtonController: NSObject {
    public static let shared = FLEXReplicaFloatingButtonController()

    private weak var buttonWindow: UIWindow?
    private weak var button: UIButton?

    public func install() {
        guard let window = foregroundKeyWindow() else { return }
        if buttonWindow === window, button != nil { return }
        button?.removeFromSuperview()

        let control = UIButton(type: .system)
        control.setTitle("FLEX", for: .normal)
        control.titleLabel?.font = .systemFont(ofSize: 13, weight: .bold)
        control.setTitleColor(.white, for: .normal)
        control.backgroundColor = .systemIndigo
        control.layer.cornerRadius = 28
        control.layer.shadowColor = UIColor.black.cgColor
        control.layer.shadowOpacity = 0.25
        control.layer.shadowRadius = 8
        control.layer.shadowOffset = CGSize(width: 0, height: 3)
        control.accessibilityLabel = "Open FLEX inspector"
        control.accessibilityHint = "Drag to move the floating button"
        control.frame = CGRect(x: 0, y: 0, width: 56, height: 56)
        control.addTarget(self, action: #selector(didTap), for: .touchUpInside)
        control.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(didPan(_:))))

        let safeFrame = window.safeAreaLayoutGuide.layoutFrame
        control.center = CGPoint(x: safeFrame.maxX - 34,
                                 y: safeFrame.minY + safeFrame.height * 0.68)
        window.addSubview(control)
        buttonWindow = window
        button = control
    }

    public func setHidden(_ hidden: Bool) {
        button?.isHidden = hidden
    }

    @objc private func didTap() {
        FLEXReplicaMenuLauncher.showMenu()
    }

    @objc private func didPan(_ gesture: UIPanGestureRecognizer) {
        guard let control = gesture.view, let parent = control.superview else { return }
        let translation = gesture.translation(in: parent)
        control.center = CGPoint(x: control.center.x + translation.x,
                                 y: control.center.y + translation.y)
        gesture.setTranslation(.zero, in: parent)

        let safeFrame = parent.safeAreaLayoutGuide.layoutFrame
        let halfWidth = control.bounds.width / 2
        let halfHeight = control.bounds.height / 2
        control.center.x = min(max(control.center.x, safeFrame.minX + halfWidth), safeFrame.maxX - halfWidth)
        control.center.y = min(max(control.center.y, safeFrame.minY + halfHeight), safeFrame.maxY - halfHeight)
    }

    private func foregroundKeyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows)
            .first(where: { $0.isKeyWindow })
    }
}

/// C-callable entry point to present the panel manually.
@_cdecl("FLEXReplicaShowMenu")
public func FLEXReplicaShowMenu() {
#if canImport(FLEXReplicaAutoOpen)
    _ = FLEXReplicaAutoOpenEnsureLinked()
#endif
    Task { @MainActor in
        FLEXReplicaMenuLauncher.showMenu()
    }
}

/// C-callable entry point used by the initializer to install the floating control.
@_cdecl("FLEXReplicaInstallFloatingButton")
public func FLEXReplicaInstallFloatingButton() {
#if canImport(FLEXReplicaAutoOpen)
    _ = FLEXReplicaAutoOpenEnsureLinked()
#endif
    Task { @MainActor in
        FLEXReplicaFloatingButtonController.shared.install()
    }
}
#endif
