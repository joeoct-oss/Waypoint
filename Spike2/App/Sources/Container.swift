import Observation
import SwiftUI
import UIKit

// Spike A: one Waypoint container that holds either renderer, embedded anywhere.

/// The UIKit face of the container: a plain view controller that holds the stack as a child.
/// Any controller can add it as a child, present it, or use it as a tab.
final class WaypointContainerViewController: UIViewController {
    let router: StackRouter
    let renderer: Host
    private let hostGesture = HostGestureGate()

    init(router: StackRouter, renderer: Host) {
        self.router = router
        self.renderer = renderer
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        let child: UIViewController =
            switch renderer {
            case .uiKit:
                StackNavigationController(router: router)
            case .swiftUI:
                UIHostingController(rootView: StackView(router: router))
            }
        addChild(child)
        child.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(child.view)
        NSLayoutConstraint.activate([
            child.view.topAnchor.constraint(equalTo: view.topAnchor),
            child.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            child.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            child.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        child.didMove(toParent: self)
        if parent is UINavigationController || navigationController != nil {
            SpikeLog.shared.note("container inside a foreign UINavigationController")
        }
    }

    /// `-adapt`: inside a foreign navigation controller, hide the host's bar while the container
    /// shows, and give the container's root screen a back button that pops the host.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard Launch.flag("adapt"), let host = navigationController else { return }
        host.setNavigationBarHidden(true, animated: animated)
        // A hidden bar turns off the host's swipe back; this common workaround turns it on again,
        // so a swipe at the container's root leaves the container.
        if Launch.flag("hostSwipe") {
            // Only when the container shows its root; otherwise the container's own stack pops.
            hostGesture.router = router
            host.interactivePopGestureRecognizer?.delegate = hostGesture
            host.interactivePopGestureRecognizer?.isEnabled = true
        }
        let previous = host.viewControllers.dropLast().last?.title ?? "Back"
        ContainerExit.shared.set(title: previous) { [weak host] in host?.popViewController(animated: true) }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard Launch.flag("adapt"), let host = navigationController, isMovingFromParent else { return }
        host.setNavigationBarHidden(false, animated: animated)
        ContainerExit.shared.clear()
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        if parent is UINavigationController {
            SpikeLog.shared.note("container pushed onto a foreign UINavigationController")
        }
    }
}

/// Lets the host's swipe back start only while the container shows its root screen.
final class HostGestureGate: NSObject, UIGestureRecognizerDelegate {
    weak var router: StackRouter?

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        MainActor.assumeIsolated { router?.path.isEmpty ?? true }
    }
}

/// The SwiftUI face of the container.
struct WaypointContainer: View {
    let router: StackRouter
    let renderer: Host

    var body: some View {
        switch renderer {
        case .swiftUI:
            StackView(router: router)
        case .uiKit:
            UIKitStack(router: router).ignoresSafeArea(.container, edges: .bottom)
        }
    }
}

// MARK: Hosts: "existing app" code that embeds the container

/// An existing UIKit screen that is not in a navigation controller. `-host uikitChild` embeds the
/// container under a header; `-host uikitPresent` presents it from a button.
final class LegacyHostViewController: UIViewController {
    let embeds: Bool

    init(embeds: Bool) {
        self.embeds = embeds
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .secondarySystemBackground
        let header = UILabel()
        header.text = "Existing app header"
        header.accessibilityIdentifier = "host.header"
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            header.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
        if embeds {
            let container = WaypointContainerViewController(router: Roots.main, renderer: Launch.renderer)
            addChild(container)
            container.view.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(container.view)
            NSLayoutConstraint.activate([
                container.view.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 12),
                container.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                container.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                container.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ])
            container.didMove(toParent: self)
        } else {
            addOpenButton(below: header)
        }
    }

    private func addOpenButton(below header: UIView) {
        var config = UIButton.Configuration.filled()
        config.title = "openFlow"
        let button = UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in
            let container = WaypointContainerViewController(router: Roots.main, renderer: Launch.renderer)
            if self?.navigationController != nil {
                self?.navigationController?.pushViewController(container, animated: true)
            } else {
                self?.present(container, animated: true)
            }
        })
        button.accessibilityIdentifier = "openFlow"
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 40),
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }
}

/// `-host swiftuiHost`: an existing SwiftUI screen with the container under a header.
struct SwiftUIHostView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Existing app header").accessibilityIdentifier("host.header")
            WaypointContainer(router: Roots.main, renderer: Launch.renderer)
        }
        .background(Color(.secondarySystemBackground))
    }
}

/// `-host swiftuiNested`: an existing SwiftUI app that already has a NavigationStack pushes a
/// screen holding the container.
struct SwiftUINestedHostView: View {
    var body: some View {
        NavigationStack {
            List {
                Text("Existing app list").accessibilityIdentifier("host.header")
                NavigationLink("openFlow") {
                    NestedContainer()
                }
                .accessibilityIdentifier("openFlow")
            }
            .navigationTitle("Host")
        }
    }
}

/// The root controller for scenario A, from `-host`.
@MainActor
func makeScenarioARoot() -> UIViewController {
    switch Launch.value("host") ?? "uikitChild" {
    case "uikitPresent":
        return LegacyHostViewController(embeds: false)
    case "foreignNav":
        let host = LegacyHostViewController(embeds: false)
        host.title = "Host"
        return UINavigationController(rootViewController: host)
    case "swiftuiHost":
        return UIHostingController(rootView: SwiftUIHostView())
    case "swiftuiNested":
        return UIHostingController(rootView: SwiftUINestedHostView())
    case "uikitTabs":
        let tabs = UITabBarController()
        let first = WaypointContainerViewController(router: Roots.main, renderer: .swiftUI)
        first.tabBarItem = UITabBarItem(title: "SwiftUI", image: UIImage(systemName: "a.circle"), tag: 0)
        let second = WaypointContainerViewController(router: StackRouter(name: "second", rootTitle: "Root2"), renderer: .uiKit)
        second.tabBarItem = UITabBarItem(title: "UIKit", image: UIImage(systemName: "b.circle"), tag: 1)
        tabs.viewControllers = [first, second]
        return tabs
    default:
        return LegacyHostViewController(embeds: true)
    }
}

/// `-adapt` for a SwiftUI host stack: hide the host's bar and exit through the container's root.
struct NestedContainer: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if Launch.flag("adapt") {
            WaypointContainer(router: Roots.main, renderer: Launch.renderer)
                .toolbar(.hidden, for: .navigationBar)
                .onAppear { ContainerExit.shared.set(title: "Host") { dismiss() } }
        } else {
            WaypointContainer(router: Roots.main, renderer: Launch.renderer)
        }
    }
}

/// The way out of a container that sits inside the host's own stack, shown on the container's root screen.
@MainActor
@Observable
final class ContainerExit {
    static let shared = ContainerExit()
    private(set) var title: String?
    @ObservationIgnored private var action: (() -> Void)?

    func set(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    func clear() {
        title = nil
        action = nil
    }

    func exit() {
        let action = action
        clear()
        action?()
    }
}
