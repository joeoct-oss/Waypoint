import Observation
import SwiftUI
import UIKit

/// Renders a StackRouter with a UINavigationController.
final class StackNavigationController: UINavigationController, UINavigationControllerDelegate,
    UIAdaptivePresentationControllerDelegate
{
    let router: StackRouter
    private var routeControllers: [(route: AnyRoute, controller: UIViewController)] = []

    init(router: StackRouter) {
        self.router = router
        super.init(nibName: nil, bundle: nil)
        delegate = self
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
        } onChange: { [weak self] in
            // onChange runs before the change is stored, so render on the next main-actor turn.
            Task { @MainActor in
                self?.render(animated: true)
                self?.observe()
            }
        }
    }

    private func render(animated: Bool) {
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
            // One call for any number of pushes or pops: UIKit animates only the top change.
            setViewControllers(desired, animated: animated)
        }

        if let presentation = router.presented, presentedViewController == nil {
            let child: UIViewController =
                switch presentation.host {
                case .uiKit: StackNavigationController(router: presentation.router)
                case .swiftUI: UIHostingController(rootView: StackView(router: presentation.router))
                }
            child.presentationController?.delegate = self
            present(child, animated: animated)
        } else if router.presented == nil, let shown = presentedViewController, !shown.isBeingDismissed {
            dismiss(animated: animated)
        }
    }

    private func makeController(for route: AnyRoute) -> UIViewController {
        if route.base is ProductRoute {
            // UIKit pushes a SwiftUI screen.
            let host = UIHostingController(rootView: SpikeScreen(router: router, title: route.title))
            host.title = route.title
            return host
        }
        return SpikeViewController(router: router, title: route.title)
    }

    // User-driven pops: back button, swipe back, long-press back menu.
    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        let count = viewControllers.count - 1
        if count < routeControllers.count { routeControllers.removeLast(routeControllers.count - count) }
        router.rendererDidShow(count: count, source: "uikit")
    }

    // User-driven dismissal: swipe down on a sheet this controller presented.
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        router.rendererDidDismiss(source: "uikit")
    }
}

final class SpikeViewController: UIViewController {
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
        let debug = UIHostingController(rootView: DebugState())
        addChild(debug)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 6
        stack.addArrangedSubview(debug.view)
        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 6
        var row: UIStackView?
        for (index, action) in SpikeAction.all.enumerated() {
            if index % 2 == 0 {
                row = UIStackView()
                row?.distribution = .fillEqually
                row?.spacing = 6
                grid.addArrangedSubview(row!)
            }
            var config = UIButton.Configuration.bordered()
            config.title = action.id
            let button = UIButton(configuration: config, primaryAction: UIAction { [router] _ in action.run(router) })
            button.accessibilityIdentifier = action.id
            row?.addArrangedSubview(button)
        }
        stack.addArrangedSubview(grid)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
        ])
        debug.didMove(toParent: self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AppRouter.shared.didAppear(title ?? "?")
    }
}
