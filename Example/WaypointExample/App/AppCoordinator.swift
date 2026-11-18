//
//  AppCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// The app's navigation starts here (decision 0009). The app asks for each window's view with
// `makeWindow(services:launch:)`, and each call makes a new coordinator, so two iPad windows never
// share a root or a stack. The coordinator owns the root: the splash, then the main tabs, which
// guests and signed-in readers share; an action that needs an account asks for it in a sheet over
// the tabs. Clear all data in Settings clears the store and starts the window over from the splash.
// Screens report, coordinators decide: `make…Flow()` builds a flow, `show…()` navigates.
//
// Until the SwiftUI renderer is built, coordinators keep plain SwiftUI state (a root, a path, a
// selected tab, a presented sheet). Each piece is the seam for one Waypoint router: the root
// becomes a root router, paths become stack routers, the tab selection a tab router, and
// `makeWindow(services:launch:)` returns `WaypointRoot { AppCoordinator(...) }`. The screens and
// their callbacks stay as they are.
//
// Conformances:
// - `Observable` (from `@Observable`), so the window redraws when the root switches.
@MainActor
@Observable
final class AppCoordinator {
    static func makeWindow(
        services: AppServices,
        launch: LaunchOptions
    ) -> some View {
        AppWindow {
            AppCoordinator(
                services: services,
                launch: launch
            )
        }
    }

    private let services: AppServices
    // `var` because Clear all data starts the window over without the launch's own destination.
    private var launch: LaunchOptions
    // `var` because `showMainFlow()` and `startOver()` switch it.
    private(set) var root: AppRoot

    init(
        services: AppServices,
        launch: LaunchOptions
    ) {
        self.services = services
        self.launch = launch
        root = .splash
    }

    @ViewBuilder
    func makeFlow(for root: AppRoot) -> some View {
        switch root {
        case .splash:
            makeSplashFlow()
        case .main(let main):
            makeMainFlow(main)
        }
    }

    func showMainFlow() {
        let main = MainCoordinator(
            services: services,
            launch: launch,
            onClearAllData: { [weak self] in self?.startOver() }
        )
        root = .main(main)
    }

    func startOver() {
        services.clearAll()
        launch = launch.startingOver()
        root = .splash
    }

    private func makeSplashFlow() -> some View {
        SplashView(
            duration: launch.splashDuration,
            onFinished: { self.showMainFlow() }
        )
    }

    private func makeMainFlow(_ main: MainCoordinator) -> some View {
        MainTabView(main: main)
    }
}
