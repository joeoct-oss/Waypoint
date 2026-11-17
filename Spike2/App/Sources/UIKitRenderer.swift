import Observation
import SwiftUI
import UIKit

/// The renderer spike's UIKit stack, with the same three additions as `StackView`.
final class StackNavigationController: UINavigationController, UINavigationControllerDelegate,
    UIAdaptivePresentationControllerDelegate
{
    let router: StackRouter
    private var routeControllers: [(route: AnyRoute, controller: UIViewController)] = []
    private weak var shownAlert: UIAlertController?
    private var waitingForForeign = false

    init(router: StackRouter) {
        self.router = router
        super.init(nibName: nil, bundle: nil)
        delegate = self
        navigationBar.prefersLargeTitles = Launch.flag("largeTitles")
        setViewControllers([SpikeViewController(router: router, title: router.rootTitle)], animated: false)
        render(animated: false)
        observe()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func observe() {
        withObservationTracking {
            _ = router.path
            _ = router.presented
            _ = router.alert
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.render(animated: true)
                self?.observe()
            }
        }
    }

    func render(animated: Bool) {
        renderStack(animated: animated)
        renderPresentation(animated: animated)
        renderAlert(animated: animated)
    }

    private func renderStack(animated: Bool) {
        var matched = true
        var next: [(route: AnyRoute, controller: UIViewController)] = []
        for (index, route) in router.path.enumerated() {
            if matched, index < routeControllers.count, routeControllers[index].route == route {
                next.append(routeControllers[index])
            } else {
                matched = false
                next.append((route, makeController(for: route)))
            }
        }
        routeControllers = next
        let desired = [viewControllers[0]] + next.map(\.controller)
        if desired != viewControllers {
            setViewControllers(desired, animated: animated)
        }
    }

    // MARK: E, presentations

    /// The Waypoint flow presented by this stack, if it is on screen.
    private var ownPresented: UIViewController? {
        guard let shown = presentedViewController, OwnedPresentations.contains(shown), !(shown is UIAlertController) else {
            return nil
        }
        return shown
    }

    private func renderPresentation(animated: Bool) {
        if let presentation = router.presented, ownPresented == nil {
            if let blocker = presentedViewController, !OwnedPresentations.contains(blocker) {
                handleForeign(blocker, animated: animated)
                return
            }
            if presentedViewController != nil {
                // Our own alert or a transition: try again when it ends.
                return
            }
            let child: UIViewController =
                switch presentation.host {
                case .uiKit:
                    StackNavigationController(router: presentation.router)
                case .swiftUI:
                    UIHostingController(rootView: StackView(router: presentation.router))
                }
            child.presentationController?.delegate = self
            OwnedPresentations.insert(child)
            ForeignWatch.shared.waypointDidPresent(source: "uikit")
            present(child, animated: animated)
        } else if router.presented == nil, let shown = ownPresented, !shown.isBeingDismissed {
            dismiss(animated: animated) { [weak self] in
                SpikeLog.shared.note("uikit dismiss completed \(self?.router.name ?? "")")
                // F: an alert that waited for this dismissal can show now.
                self?.render(animated: true)
            }
        }
    }

    /// E: a controller Waypoint didn't present is in the way.
    private func handleForeign(_ blocker: UIViewController, animated: Bool) {
        let name = String(describing: type(of: blocker))
        switch ForeignWatch.policy {
        case .naive:
            SpikeLog.shared.note("foreign \(name): presenting anyway")
            let child = StackNavigationController(router: router.presented!.router)
            OwnedPresentations.insert(child)
            present(child, animated: animated)
            let shownAfter = presentedViewController.map { String(describing: type(of: $0)) } ?? "nil"
            SpikeLog.shared.note("after naive present, top=\(shownAfter)")
        case .wait:
            guard !waitingForForeign else { return }
            waitingForForeign = true
            SpikeLog.shared.note("foreignPresentation \(name): waiting")
            ForeignWatch.shared.waitUntilGone(from: self) { [weak self] in
                self?.waitingForForeign = false
                self?.render(animated: true)
            }
        case .dismiss:
            guard !blocker.isBeingDismissed else { return }
            SpikeLog.shared.note("foreignPresentation \(name): dismissing first")
            dismiss(animated: animated) { [weak self] in
                self?.render(animated: true)
            }
        }
    }

    // MARK: F, alerts

    private func renderAlert(animated: Bool) {
        guard let alert = router.alert else {
            if let shownAlert, !shownAlert.isBeingDismissed {
                if Launch.flag("sequenced") {
                    // Dismiss, then render again, so a sheet waiting behind the alert shows.
                    // UIKit runs the completion at once when the alert is already gone, so the
                    // render goes to the next turn (the first version recursed until it crashed).
                    self.shownAlert = nil
                    shownAlert.dismiss(animated: animated) { [weak self] in
                        SpikeLog.shared.note("uikit alert dismissed, render again")
                        Task { @MainActor in self?.render(animated: true) }
                    }
                } else {
                    shownAlert.dismiss(animated: animated)
                }
            }
            return
        }
        guard shownAlert == nil else { return }
        if Launch.flag("sequenced") {
            // Only on top, and never during a presentation transition.
            guard router.presented == nil, presentedViewController == nil, transitionCoordinator == nil else {
                SpikeLog.shared.note("uikit alert waits \(router.name)")
                return
            }
        }
        let controller = UIAlertController(title: alert.title, message: nil, preferredStyle: .alert)
        for button in alert.buttons {
            controller.addAction(UIAlertAction(title: button, style: .default) { [weak self] _ in
                self?.router.rendererDidAnswerAlert(button, source: "uikit")
            })
        }
        OwnedPresentations.insert(controller)
        shownAlert = controller
        present(controller, animated: animated)
        let top = presentedViewController === controller ? "alert" : "NOT SHOWN"
        SpikeLog.shared.note("uikit present alert \(router.name): \(top)")
        if presentedViewController !== controller {
            shownAlert = nil
        }
    }

    // MARK: Destinations

    private func makeController(for route: AnyRoute) -> UIViewController {
        switch route.base {
        case let product as ProductRoute:
            // A: a SwiftUI destination with `.navigationTitle` and `.toolbar` in a UIKit stack.
            return UIHostingController(rootView: ProductScreen(router: router, route: product))
        case let legacy as LegacyRoute:
            return LegacyViewController(router: router, route: legacy)
        default:
            return SpikeViewController(router: router, title: route.title)
        }
    }

    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        let count = viewControllers.count - 1
        if count < routeControllers.count { routeControllers.removeLast(routeControllers.count - count) }
        router.rendererDidShow(count: count, source: "uikit")
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        router.rendererDidDismiss(source: "uikit")
    }
}

class SpikeViewController: UIViewController {
    let router: StackRouter

    init(router: StackRouter, title: String) {
        self.router = router
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let content = UIHostingController(rootView: ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                DebugState()
                ActionGrid(router: router)
            }
            .padding()
        })
        addChild(content)
        content.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(content.view)
        NSLayoutConstraint.activate([
            content.view.topAnchor.constraint(equalTo: view.topAnchor),
            content.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            content.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            content.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        content.didMove(toParent: self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if title == router.rootTitle, router.name == "main", let exitTitle = ContainerExit.shared.title {
            let item = UIBarButtonItem(title: exitTitle, primaryAction: UIAction { _ in ContainerExit.shared.exit() })
            item.accessibilityIdentifier = "container.exit"
            navigationItem.leftBarButtonItem = item
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        SpikeLog.shared.didAppear(title ?? "?")
    }
}

/// A: an "existing" UIKit screen with its own bar button, used as a destination in both renderers.
final class LegacyViewController: SpikeViewController {
    init(router: StackRouter, route: LegacyRoute) {
        super.init(router: router, title: route.title)
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Edit",
            primaryAction: UIAction { _ in SpikeLog.shared.note("edit tapped \(route.title)") }
        )
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "toolbar.Edit"
        view.accessibilityIdentifier = "legacy.\(route.title)"
    }
}
