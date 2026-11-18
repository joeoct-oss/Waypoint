//
//  AppCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// The app's navigation starts here (decision 0009). Each window makes its own app coordinator. It owns
// the root: the splash, then the accounts flow or the main tabs, and it switches between them when a flow
// reports that the reader signed in, chose to browse as a guest, or signed out. Screens report,
// coordinators decide: `make…Flow()` builds a flow, `show…()` navigates.
//
// Until the SwiftUI renderer is built, coordinators keep plain SwiftUI state (a root, a path, a selected
// tab, a presented sheet). Each piece is the seam for one Waypoint router: the root becomes a root router,
// paths become stack routers, the tab selection a tab router, and `AppRootView` becomes
// `WaypointRoot { AppCoordinator(...) }`. The screens and their callbacks stay as they are.
//
// Conformances:
// - `Observable` (from `@Observable`), so `AppRootView` redraws when the root switches.
@MainActor
@Observable
final class AppCoordinator {
    private let launch: LaunchOptions
    // `var` because `showAuthFlow()` and `showMainFlow()` switch it.
    private(set) var root: AppRoot

    init(launch: LaunchOptions) {
        self.launch = launch
        root = .splash
    }

    @ViewBuilder
    func makeFlow(for root: AppRoot) -> some View {
        switch root {
        case .splash:
            makeSplashFlow()
        case .auth(let auth):
            makeAuthFlow(auth)
        case .main(let main):
            makeMainFlow(main)
        }
    }

    func showStartFlow() {
        if let membership = launch.startMembership {
            showMainFlow(as: membership)
        } else {
            showAuthFlow()
        }
    }

    func showAuthFlow() {
        let auth = AuthCoordinator(onFinish: { [weak self] in self?.showMainFlow(as: $0) })
        root = .auth(auth)
    }

    func showMainFlow(as membership: Membership) {
        let main = MainCoordinator(
            membership: membership,
            launch: launch,
            onShowAccounts: { [weak self] in self?.showAuthFlow() }
        )
        root = .main(main)
    }

    private func makeSplashFlow() -> some View {
        SplashView(
            duration: launch.splashDuration,
            onFinished: { self.showStartFlow() }
        )
    }

    private func makeAuthFlow(_ auth: AuthCoordinator) -> some View {
        AuthFlowView(auth: auth)
    }

    private func makeMainFlow(_ main: MainCoordinator) -> some View {
        MainTabView(main: main)
    }
}
