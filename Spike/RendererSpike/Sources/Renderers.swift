//
//  Renderers.swift
//  RendererSpike (#250, throwaway)
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import UIKit

// MARK: - SwiftUI renderer

/// `NavigationStack(path:)` bound to the model, with the mid-transition hold
/// the package's SwiftUI stack uses (#11, #204). `-hold 0` turns it off.
struct SwiftUIStackRenderer: View {
    let model: PathModel
    let tab: String
    let config: LaunchConfig

    @State private var shown: [Route] = []
    @State private var holdUntil = Date.distantPast
    @State private var pending: DispatchWorkItem?

    var body: some View {
        NavigationStack(path: Binding(get: { shown }, set: { NSLog("SPIKE binding set %@ (shown %@, model %@)", $0.map { String($0.number) }.joined(separator: ","), shown.map { String($0.number) }.joined(separator: ","), model.debugText); shown = $0; model.path = $0 })) {
            RootScreen(tab: tab)
                .navigationDestination(for: Route.self) { route in
                    PushedScreen(route: route, model: model, hidesTabBar: config.hidesTabBar)
                }
        }
        .environment(\.routerStandIn, "router-\(tab)")
        .onAppear { shown = model.path }
        .onChange(of: model.path) { _, newPath in apply(newPath) }
    }

    private func apply(_ newPath: [Route]) {
        guard newPath != shown else { return }
        guard config.hold else { shown = newPath; return }
        let now = Date()
        if now < holdUntil {
            pending?.cancel()
            let work = DispatchWorkItem { apply(model.path) }
            pending = work
            DispatchQueue.main.asyncAfter(deadline: .now() + holdUntil.timeIntervalSince(now), execute: work)
        } else {
            shown = newPath
            holdUntil = now.addingTimeInterval(0.6)
        }
    }
}

// MARK: - UIKit renderer

/// A `UINavigationController` driven by the model. Diffs the path into
/// `setViewControllers(_:animated:)`, holds changes that arrive while a
/// transition runs, and reports user pops back to the model.
struct UIKitStackRenderer: UIViewControllerRepresentable {
    let path: [Route]
    let model: PathModel
    let tab: String
    let config: LaunchConfig
    let theme: Theme

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UINavigationController {
        let coordinator = context.coordinator
        coordinator.renderer = self
        coordinator.environment = context.environment
        let nav = UINavigationController(rootViewController: coordinator.rootController)
        nav.navigationBar.prefersLargeTitles = true
        nav.delegate = coordinator
        coordinator.nav = nav
        coordinator.apply(path, animated: false)
        return nav
    }

    func updateUIViewController(_ nav: UINavigationController, context: Context) {
        let coordinator = context.coordinator
        coordinator.renderer = self
        coordinator.environment = context.environment
        coordinator.refreshRootViews()
        coordinator.apply(path, animated: true)
    }

    @MainActor
    final class Coordinator: NSObject, UINavigationControllerDelegate {
        var renderer: UIKitStackRenderer!
        var environment = EnvironmentValues()
        weak var nav: UINavigationController?

        private var controllers: [UUID: UIHostingController<AnyView>] = [:]
        private var routes: [UUID: Route] = [:]
        private var transitioning = false
        private var transitionToken = 0
        private var pendingPath: [Route]?
        private var lastApplied: [Route] = []
        private(set) lazy var rootController: UIHostingController<AnyView> = {
            let hosting = UIHostingController(rootView: rootView())
            if rendererChrome {
                hosting.navigationItem.title = renderer.tab == "A" ? "Root" : "Second Root"
                hosting.navigationItem.largeTitleDisplayMode = .always
            }
            return hosting
        }()

        // MARK: Hosting

        private func wrap(_ view: some View) -> AnyView {
            let tagged = view.environment(\.routerStandIn, "router-\(renderer.tab)")
            switch renderer.config.environmentMode {
            case .none:
                return AnyView(tagged)
            case .keys:
                return AnyView(
                    tagged
                        .environment(\.spikeValue, environment.spikeValue)
                        .environment(renderer.theme)
                )
            case .whole:
                // The router stand-in must sit inside, so the whole
                // environment does not overwrite it.
                return AnyView(
                    view
                        .environment(\.routerStandIn, "router-\(renderer.tab)")
                        .environment(\.self, environment)
                        .environment(\.routerStandIn, "router-\(renderer.tab)")
                )
            }
        }

        private func rootView() -> AnyView { wrap(RootScreen(tab: renderer.tab)) }

        /// SwiftUI chrome (`navigationTitle`) is not bridged into the hosting
        /// controller's navigation item here (iOS 17.5 and 27.2), so by
        /// default the renderer sets the title itself from the route.
        /// `-uikitChrome swiftUI` turns that off to test SwiftUI chrome alone.
        private var rendererChrome: Bool {
            UserDefaults.standard.string(forKey: "uikitChrome") != "swiftUI"
        }

        private func screenView(_ route: Route) -> AnyView {
            wrap(PushedScreen(route: route, model: renderer.model, hidesTabBar: renderer.config.hidesTabBar))
        }

        private func controller(for route: Route) -> UIHostingController<AnyView> {
            if let existing = controllers[route.id] { return existing }
            let hosting = UIHostingController(rootView: screenView(route))
            if renderer.config.hidesTabBar { hosting.hidesBottomBarWhenPushed = true }
            if rendererChrome {
                hosting.navigationItem.title = "Screen \(route.number)"
                hosting.navigationItem.largeTitleDisplayMode = .never
            }
            if UserDefaults.standard.bool(forKey: "supplementBack") {
                hosting.navigationItem.leftItemsSupplementBackButton = true
            }
            controllers[route.id] = hosting
            routes[route.id] = route
            return hosting
        }

        func refreshRootViews() {
            rootController.rootView = rootView()
            for (id, hosting) in controllers {
                if let route = routes[id] { hosting.rootView = screenView(route) }
            }
        }

        // MARK: Diffing

        func apply(_ path: [Route], animated: Bool) {
            guard let nav else { return }
            if transitioning {
                pendingPath = path
                return
            }
            let wanted: [UIViewController] = [rootController] + path.map(controller(for:))
            let wantedIDs = Set(path.map(\.id))
            for id in controllers.keys where !wantedIDs.contains(id) {
                controllers[id] = nil
                routes[id] = nil
            }
            lastApplied = path
            guard wanted != nav.viewControllers else { return }
            nav.setViewControllers(wanted, animated: animated && nav.view.window != nil)
        }

        private func shownPath() -> [Route] {
            nav?.viewControllers.dropFirst().compactMap { controller in
                controllers.first { $0.value === controller }.flatMap { routes[$0.key] }
            } ?? []
        }

        // MARK: Transitions

        func navigationController(
            _ navigationController: UINavigationController,
            willShow viewController: UIViewController,
            animated: Bool
        ) {
            guard animated, let coordinator = navigationController.transitionCoordinator else { return }
            transitioning = true
            transitionToken += 1
            let token = transitionToken
            coordinator.animate(alongsideTransition: nil) { [weak self] _ in
                // Fires for finished and cancelled (interactive) transitions.
                guard let self, token == self.transitionToken else { return }
                self.transitionEnded()
            }
        }

        func navigationController(
            _ navigationController: UINavigationController,
            didShow viewController: UIViewController,
            animated: Bool
        ) {
            // Animated transitions end in the coordinator's completion above.
            // Ending here too would clear the hold while a held change that
            // was just applied is animating.
            if !transitioning { transitionEnded() }
        }

        private func transitionEnded() {
            transitioning = false
            if let pending = pendingPath {
                pendingPath = nil
                apply(pending, animated: true)
                return
            }
            // A user pop (back button or swipe): report it to the model.
            // Compare with what the renderer applied, not with the model,
            // which may already hold a newer change not yet applied.
            let shown = shownPath()
            if shown != lastApplied {
                lastApplied = shown
                renderer.model.path = shown
            }
        }
    }
}
