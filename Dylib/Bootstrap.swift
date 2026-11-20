import UIKit
import SwiftUI
#if canImport(FLEXReplicaCore)
import FLEXReplicaCore
#endif

// MARK: - Entry point (chamado por entry.c)

/// Executado pelo constructor quando a dylib carrega: dyld roda os initializers na thread principal,
/// antes de o app terminar de subir.
@_cdecl("flexreplica_start")
public func flexreplicaStart() {
    // Passo 1: reaplica os patches salvos o mais cedo possível (síncrono, para pegar métodos chamados no launch).
    // PatchManager é @MainActor e aqui já estamos na main thread; o cast só remove a anotação de
    // isolamento (não existe checagem em runtime no modo Swift 5). Fora da main thread, adia.
    let apply: @MainActor () -> Void = { PatchManager.shared.applyEnabledPatches() }
    if Thread.isMainThread {
        unsafeBitCast(apply, to: (() -> Void).self)()
    } else {
        DispatchQueue.main.async { unsafeBitCast(apply, to: (() -> Void).self)() }
    }

    // Passo 2: quando o app ficar ativo, tenta de novo (classes carregadas sob demanda) e instala os botões.
    NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                           object: nil, queue: .main) { _ in
        Task { @MainActor in
            PatchManager.shared.applyEnabledPatches()
            FLEXReplicaOverlay.shared.installIfNeeded()
        }
    }
}

// MARK: - Overlay

@MainActor
final class FLEXReplicaOverlay {
    static let shared = FLEXReplicaOverlay()
    private var window: UIWindow?

    func installIfNeeded() {
        guard window == nil else { return }
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else { return }
        let window = PassthroughWindow(windowScene: scene)
        window.windowLevel = UIWindow.Level.alert + 100
        window.backgroundColor = .clear
        window.rootViewController = OverlayViewController()
        window.isHidden = false          // não chama makeKey(): não rouba o foco do app
        self.window = window
    }
}

/// Janela que só captura toques nos próprios controles (botões / painel / captura); o resto passa para o app.
final class PassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hit = super.hitTest(point, with: event) else { return nil }
        return hit === rootViewController?.view ? nil : hit
    }
}

@MainActor
final class OverlayViewController: UIViewController, UIAdaptivePresentationControllerDelegate {
    private lazy var pickButton = makeButton(symbol: "viewfinder", action: #selector(togglePick))
    private lazy var panelButton = makeButton(symbol: "ladybug.fill", action: #selector(openPanelTapped))
    private let controls = UIStackView()
    private let highlight = UIView()
    private var captureView: UIView?
    private var selection: ViewSelection?
    private weak var previousKeyWindow: UIWindow?

    // MARK: Setup

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        controls.axis = .vertical
        controls.spacing = 8
        controls.addArrangedSubview(pickButton)
        controls.addArrangedSubview(panelButton)
        controls.frame = CGRect(x: 16, y: 140, width: 48, height: 104)
        controls.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(drag(_:))))
        view.addSubview(controls)
    }

    private func makeButton(symbol: String, action: Selector) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: symbol)
        config.cornerStyle = .capsule
        let button = UIButton(configuration: config)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.widthAnchor.constraint(equalToConstant: 48).isActive = true
        button.heightAnchor.constraint(equalToConstant: 48).isActive = true
        return button
    }

    @objc private func drag(_ gesture: UIPanGestureRecognizer) {
        let t = gesture.translation(in: view)
        gesture.setTranslation(.zero, in: view)
        let bounds = view.bounds.inset(by: view.safeAreaInsets)
        let halfW = controls.bounds.width / 2, halfH = controls.bounds.height / 2
        let x = min(max(controls.center.x + t.x, bounds.minX + halfW), bounds.maxX - halfW)
        let y = min(max(controls.center.y + t.y, bounds.minY + halfH), bounds.maxY - halfH)
        controls.center = CGPoint(x: x, y: y)
    }

    // MARK: Seleção de view por toque

    @objc private func togglePick() {
        if captureView != nil { endCapture(); return }
        guard presentedViewController == nil else { return }
        let capture = UIView(frame: view.bounds)
        capture.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        capture.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.06)
        capture.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapCapture(_:))))
        view.insertSubview(capture, at: 0)         // abaixo dos botões, acima do realce
        captureView = capture
        pickButton.configuration?.baseBackgroundColor = .systemGreen
    }

    private func endCapture() {
        captureView?.removeFromSuperview()
        captureView = nil
        pickButton.configuration?.baseBackgroundColor = nil
    }

    @objc private func didTapCapture(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: view)
        endCapture()
        guard let overlayWindow = view.window,
              let target = HostViewFinder.view(at: point, from: overlayWindow) else { return }
        showDetails(for: target)
    }

    private func showDetails(for target: UIView) {
        let model = ViewSelection(view: target) { [weak self] in self?.updateHighlight(for: $0) }
        selection = model
        updateHighlight(for: target)

        let content = ViewDetailSheet(selection: model,
                                      onBrowseClass: { [weak self] name in self?.browseClass(name) },
                                      onClose: { [weak self] in self?.closeSheet() })
        let host = UIHostingController(rootView: content)
        host.modalPresentationStyle = .pageSheet
        if let sheetController = host.sheetPresentationController {
            sheetController.detents = [.medium(), .large()]
            sheetController.largestUndimmedDetentIdentifier = .medium   // o app e o realce continuam visíveis
        }
        presentSheet(host)
    }

    private func updateHighlight(for target: UIView) {
        guard let overlayWindow = view.window else { return }
        let inTargetWindow = target.convert(target.bounds, to: nil)
        let rect = overlayWindow.convert(inTargetWindow, from: target.window)
        if highlight.superview == nil {
            highlight.isUserInteractionEnabled = false
            highlight.layer.borderColor = UIColor.systemGreen.cgColor
            highlight.layer.borderWidth = 2
            highlight.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.15)
            view.insertSubview(highlight, at: 0)
        }
        highlight.frame = rect
    }

    // MARK: Painel (navegador de classes / patches)

    @objc private func openPanelTapped() { openPanel(initialClass: nil) }

    private func openPanel(initialClass: String?) {
        guard presentedViewController == nil else { return }
        endCapture()
        let host = UIHostingController(rootView: PanelContainer(initialClass: initialClass,
                                                                onClose: { [weak self] in self?.closeSheet() }))
        host.modalPresentationStyle = .pageSheet
        presentSheet(host)
    }

    private func browseClass(_ name: String) {
        dismiss(animated: true) { [weak self] in
            self?.didCloseSheet()
            self?.openPanel(initialClass: name)
        }
    }

    // MARK: Apresentação / foco

    private func presentSheet(_ host: UIViewController) {
        guard presentedViewController == nil else { return }
        previousKeyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow && $0 !== view.window }
        host.presentationController?.delegate = self
        view.window?.makeKey()           // necessário para o teclado funcionar nos campos de texto
        present(host, animated: true)
    }

    private func closeSheet() {
        dismiss(animated: true) { [weak self] in self?.didCloseSheet() }
    }

    private func didCloseSheet() {
        highlight.removeFromSuperview()
        selection = nil
        previousKeyWindow?.makeKey()
    }

    // Fechou arrastando o sheet para baixo.
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        didCloseSheet()
    }
}

@MainActor
struct PanelContainer: View {
    let initialClass: String?
    let onClose: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Close", action: onClose).padding([.top, .horizontal])
            }
            FLEXReplicaPanel(initialClass: initialClass)
        }
    }
}
