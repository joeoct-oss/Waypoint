//
//  AppCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// The app's navigation lives here, and only here (decision 0009). The `App` holds this coordinator and
// nothing else, screens report what the reader did, and the coordinator decides where that goes:
// `make…Flow()` builds a screen, `show…()` navigates.
//
// Until the SwiftUI renderer is built, the coordinator keeps a plain `NavigationStack` path. That path is
// the one seam to change when it is: it becomes the coordinator's router, and `AppRootView` becomes
// `WaypointRoot(app)`. The screens and their callbacks stay as they are.
//
// Conformances:
// - `Observable` (from `@Observable`), so `AppRootView` redraws when the path changes.
@MainActor
@Observable
final class AppCoordinator {
    // `var` because `showBranch(_:)` and `showFlow(_:)` push onto it, and `syncPath(_:)` takes the pops the
    // stack makes itself, from the back button and the swipe.
    private(set) var path: [AppScreen]

    init(launch: LaunchOptions) {
        path = Self.makePath(for: launch)
    }

    private static func makePath(for launch: LaunchOptions) -> [AppScreen] {
        guard let branch = launch.branch else {
            return []
        }
        let branchScreen = AppScreen.branch(branch)
        guard let entry = launch.entry else {
            return [branchScreen]
        }
        return [branchScreen, .flow(entry)]
    }

    func makeHomeFlow() -> some View {
        HomeView(onSelectBranch: { self.showBranch($0) })
            .screenChrome(
                title: AppScreen.homeTitle,
                kind: nil,
                trail: AppScreen.homeTrail
            )
    }

    func makeDestination(for screen: AppScreen) -> some View {
        makeScreen(for: screen)
            .screenChrome(
                title: screen.title,
                kind: screen.kind,
                trail: screen.trail
            )
    }

    func showBranch(_ branch: Branch) {
        path.append(.branch(branch))
    }

    func showFlow(_ entry: FlowEntry) {
        path.append(.flow(entry))
    }

    func syncPath(_ newPath: [AppScreen]) {
        path = newPath
    }

    @ViewBuilder
    private func makeScreen(for screen: AppScreen) -> some View {
        switch screen {
        case .branch(let branch):
            makeBranchFlow(branch)
        case .flow(let entry):
            makePlaceholderFlow(entry)
        }
    }

    @ViewBuilder
    private func makeBranchFlow(_ branch: Branch) -> some View {
        switch branch {
        case .swiftUI:
            makeSwiftUIBranchFlow()
        case .uiKit:
            makeUIKitBranchFlow()
        }
    }

    private func makeSwiftUIBranchFlow() -> some View {
        SwiftUIBranchView(onSelect: { self.showFlow($0) })
    }

    private func makeUIKitBranchFlow() -> some View {
        UIKitBranchView(onSelect: { self.showFlow($0) })
    }

    @ViewBuilder
    private func makePlaceholderFlow(_ entry: FlowEntry) -> some View {
        switch entry.kind {
        case .swiftUI:
            makeSwiftUIPlaceholder(entry)
        case .uiKit:
            makeUIKitPlaceholder(entry)
        }
    }

    private func makeSwiftUIPlaceholder(_ entry: FlowEntry) -> some View {
        PlaceholderView(entry: entry)
    }

    private func makeUIKitPlaceholder(_ entry: FlowEntry) -> some View {
        PlaceholderControllerView(entry: entry)
    }
}
