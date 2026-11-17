import SafariServices
import SwiftUI
import UIKit
import UserNotifications

/// Controllers Waypoint presented. Anything else in the presentation chain is foreign.
@MainActor
enum OwnedPresentations {
    private final class Box {
        weak var controller: UIViewController?
        init(_ controller: UIViewController) { self.controller = controller }
    }

    private static var boxes: [Box] = []

    static func insert(_ controller: UIViewController) {
        boxes.removeAll { $0.controller == nil }
        boxes.append(Box(controller))
    }

    static func contains(_ controller: UIViewController) -> Bool {
        boxes.contains { $0.controller === controller }
    }
}

/// Placed inside Waypoint's SwiftUI sheet content: marks the presented controller SwiftUI made as owned.
struct OwnedPresentationMarker: UIViewRepresentable {
    func makeUIView(context: Context) -> MarkerView { MarkerView() }
    func updateUIView(_ view: MarkerView, context: Context) { }

    final class MarkerView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            // The nearest controller above this view, then its outermost container: the
            // controller SwiftUI presented. (The responder chain goes on to the presenter, so
            // the first version, which took the last controller in the chain, marked nothing.)
            var responder: UIResponder? = self
            var controller: UIViewController?
            while let next = responder?.next, controller == nil {
                controller = next as? UIViewController
                responder = next
            }
            var top = controller
            while let parent = top?.parent { top = parent }
            if let top, top.presentingViewController != nil {
                OwnedPresentations.insert(top)
                SpikeLog.shared.note("marked owned \(type(of: top))")
            }
        }
    }
}

enum ForeignPolicy: String {
    case naive, wait, dismiss
}

/// E: finds foreign presentations and tells the renderers when they are gone.
@MainActor
@Observable
final class ForeignWatch {
    static let shared = ForeignWatch()
    static var policy: ForeignPolicy { ForeignPolicy(rawValue: Launch.value("policy") ?? "wait") ?? .wait }

    /// True while a Waypoint presentation is held back by a foreign one.
    private(set) var blocked = false
    @ObservationIgnored private var link: CADisplayLink?
    @ObservationIgnored private var onGone: [() -> Void] = []
    @ObservationIgnored private var goneAt: Date?
    @ObservationIgnored var foreignClosedAt: Date?
    @ObservationIgnored private var checks = 0

    // MARK: Finding

    /// The app's main window. `-keyWindowOnly` uses the key window, which the first run did.
    static var window: UIWindow? {
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        if Launch.flag("keyWindowOnly") {
            return windows.first { $0.isKeyWindow }
        }
        // The window that holds the app's root controller: the first normal-level window with one.
        return windows.first { $0.windowLevel == .normal && $0.rootViewController != nil }
    }

    /// The first controller in the window's presentation chain that Waypoint didn't present.
    static func foreignController() -> UIViewController? {
        var current = window?.rootViewController?.presentedViewController
        while let shown = current {
            if !OwnedPresentations.contains(shown) { return shown }
            current = shown.presentedViewController
        }
        return nil
    }

    /// Every window and what its root presents, for the log.
    static func describeWindows() -> String {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).map { window in
            let root = window.rootViewController.map { String(describing: type(of: $0)) } ?? "nil"
            let shown = window.rootViewController?.presentedViewController.map { String(describing: type(of: $0)) } ?? "nil"
            return "\(type(of: window))(key=\(window.isKeyWindow) root=\(root) presents=\(shown))"
        }.joined(separator: ", ")
    }

    static var topController: UIViewController? {
        var top = window?.rootViewController
        while let next = top?.presentedViewController, !next.isBeingDismissed { top = next }
        return top
    }

    // MARK: SwiftUI side

    /// The SwiftUI sheet binding asks this before handing SwiftUI a presentation.
    var allowsPresenting: Bool {
        _ = blocked // observed, so SwiftUI asks again when it changes
        guard Self.policy != .naive, let foreign = Self.foreignController() else { return true }
        let name = String(describing: type(of: foreign))
        DispatchQueue.main.async { [self] in
            guard !blocked else { return }
            blocked = true
            if Self.policy == .dismiss, let presenter = foreign.presentingViewController, !foreign.isBeingDismissed {
                SpikeLog.shared.note("foreignPresentation \(name): dismissing first (swiftui)")
                presenter.dismiss(animated: true)
            } else {
                SpikeLog.shared.note("foreignPresentation \(name): waiting (swiftui)")
            }
            startPolling { [self] in blocked = false }
        }
        return false
    }

    func routerWantsToPresent() {
        goneAt = nil
    }

    // MARK: UIKit side

    func waitUntilGone(from controller: UIViewController, _ done: @escaping () -> Void) {
        startPolling(done)
    }

    // MARK: Polling, one check per frame

    private func startPolling(_ done: @escaping () -> Void) {
        onGone.append(done)
        guard link == nil else { return }
        checks = 0
        let target = DisplayLinkTarget { [weak self] in self?.tick() }
        let link = CADisplayLink(target: target, selector: #selector(DisplayLinkTarget.fire))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    private func tick() {
        checks += 1
        // Gone means no foreign controller and no presentation transition still running.
        if Self.foreignController() == nil, Self.window?.rootViewController?.transitionCoordinator == nil {
            link?.invalidate()
            link = nil
            goneAt = Date()
            let closed = foreignClosedAt.map { " \(Int(goneAt!.timeIntervalSince($0) * 1000)) ms after the foreign controller's viewDidDisappear" } ?? ""
            SpikeLog.shared.note("foreign gone after \(checks) frame checks\(closed)")
            let callbacks = onGone
            onGone = []
            callbacks.forEach { $0() }
        }
    }

    /// Both renderers call this when Waypoint's presentation starts.
    func waypointDidPresent(source: String) {
        guard let goneAt else { return }
        let ms = Int(Date().timeIntervalSince(goneAt) * 1000)
        SpikeLog.shared.note("held present started \(ms) ms after foreign gone (\(source))")
        self.goneAt = nil
    }
}

final class DisplayLinkTarget: NSObject {
    let action: @MainActor () -> Void
    init(_ action: @escaping @MainActor () -> Void) { self.action = action }
    @MainActor @objc func fire() { action() }
}

// MARK: Foreign presenters, as app code or an SDK would write them

@MainActor
enum ForeignActions {
    static func share() {
        let controller = UIActivityViewController(activityItems: [URL(string: "https://example.com")!], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            ForeignWatch.shared.foreignClosedAt = Date()
            SpikeLog.shared.note("share sheet completion handler")
        }
        if let popover = controller.popoverPresentationController, let view = ForeignWatch.topController?.view {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: 80, width: 1, height: 1)
        }
        let presenter = ForeignWatch.topController
        let start = Date()
        presenter?.present(controller, animated: true) {
            SpikeLog.shared.note("share present completion after \(Int(Date().timeIntervalSince(start) * 1000)) ms")
        }
        let immediately = presenter?.presentedViewController.map { String(describing: type(of: $0)) } ?? "nil"
        SpikeLog.shared.note("app presented share sheet; presenter.presentedViewController right after=\(immediately)")
        // When does the share sheet show up in the presentation chain?
        Task { @MainActor in
            for step in 1...60 {
                try? await Task.sleep(for: .milliseconds(50))
                if presenter?.presentedViewController === controller {
                    SpikeLog.shared.note("share sheet in chain after \(step * 50) ms")
                    return
                }
            }
            SpikeLog.shared.note("share sheet not in chain after 3 s")
        }
    }

    static func sdkSheet(fullScreen: Bool) {
        let controller = SDKViewController()
        controller.modalPresentationStyle = fullScreen ? .fullScreen : .pageSheet
        ForeignWatch.topController?.present(controller, animated: true)
        SpikeLog.shared.note("sdk presented \(fullScreen ? "cover" : "sheet")")
    }

    static func appAlert() {
        let alert = UIAlertController(title: "App alert", message: "Not Waypoint's", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in ForeignWatch.shared.foreignClosedAt = Date() })
        ForeignWatch.topController?.present(alert, animated: true)
        SpikeLog.shared.note("app presented alert")
    }

    static func safari() {
        let controller = SFSafariViewController(url: URL(string: "https://example.com")!)
        ForeignWatch.topController?.present(controller, animated: true)
        SpikeLog.shared.note("app presented safari")
    }

    static func systemAlert() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { granted, _ in
            Task { @MainActor in SpikeLog.shared.note("notification permission answered \(granted)") }
        }
        SpikeLog.shared.note("requested notification permission")
    }
}

/// A stand-in for a payment or consent SDK's screen.
final class SDKViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemYellow
        view.accessibilityIdentifier = "sdk.screen"
        var config = UIButton.Configuration.filled()
        config.title = "Close SDK"
        let button = UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
        button.accessibilityIdentifier = "sdk.close"
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        ForeignWatch.shared.foreignClosedAt = Date()
        SpikeLog.shared.note("sdk viewDidDisappear")
    }
}
