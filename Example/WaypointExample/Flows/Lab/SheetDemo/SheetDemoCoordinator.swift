//
//  SheetDemoCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Observation
import WaypointCore

// The Sheet story (#279): every presentation call from a button, on a stack router of the story's
// own. Its screen picks the next sheet's size and whether a swipe closes it, then presents a sheet
// or a full-screen cover. Each level presented can present another on top, ask the router that
// presented it to `dismiss` it, close itself with `dismissFlow`, or close every level with the
// story router's `dismissAll`. The story's screen shows the router's tree, and every call goes to
// the Lab's event log.
//
// The sheets and covers are still SwiftUI's, bound to the routers, until Waypoint draws them.
//
// Conformances:
// - `Observable` (from `@Observable`), so the story redraws when a level opens or closes, or the
//   size or swipe choice changes.
@MainActor
@Observable
final class SheetDemoCoordinator {
    private static let flowID = FlowID("labSheet")
    private static let rootName = "Sheet story"
    private static let firstLevel = 1

    let router: StackRouter
    private let onClose: () -> Void
    // `var` because the size picker sets it before the next sheet is presented.
    var size: SheetDemoSize
    // `var` because the swipe-to-close toggle sets it before the next sheet is presented.
    var allowsSwipe: Bool
    // `var` because each present keeps its level here, keyed by the presenting router, and
    // `release(over:)` drops it once the sheet or cover has gone, so it still draws meanwhile.
    private var levels: [ObjectIdentifier: SheetDemoLevel]

    // The story router's whole tree, as the story's screen shows it.
    var tree: String {
        router.debugTree()
    }

    private var sheetStyle: PresentationStyle {
        let options = SheetOptions(
            detents: size.detents,
            allowsInteractiveDismiss: allowsSwipe
        )
        return .sheet(options)
    }

    init(
        navigation: NavigationConfiguration,
        onClose: @escaping () -> Void
    ) {
        self.onClose = onClose
        router = StackRouter(
            flow: Self.flowID,
            configuration: navigation
        )
        size = .medium
        allowsSwipe = true
        levels = [:]
        router.setRootName(Self.rootName)
        router.setCoordinator(self)
    }

    // Whether `presenter` presents a cover (`cover`) or a sheet now.
    func isShowing(
        over presenter: StackRouter,
        cover: Bool
    ) -> Bool {
        guard let presentation = presenter.state.presentation else {
            return false
        }
        return presentation.style.isFullScreenCover == cover
    }

    // The level `presenter` presents, kept until its sheet or cover has gone.
    func level(over presenter: StackRouter) -> SheetDemoLevel? {
        levels[ObjectIdentifier(presenter)]
    }

    func presentSheet(from level: SheetDemoLevel?) {
        present(
            from: level,
            style: sheetStyle
        )
    }

    func presentCover(from level: SheetDemoLevel?) {
        present(
            from: level,
            style: .fullScreenCover
        )
    }

    // The router that presented `level` dismisses it.
    func dismiss(_ level: SheetDemoLevel) {
        level.presenter.dismiss()
    }

    // `level`'s own router asks whoever presented it to dismiss it.
    func dismissFlow(_ level: SheetDemoLevel) {
        level.router.dismissFlow()
    }

    // Closes every level in one change.
    func dismissAll() {
        router.dismissAll()
    }

    // Takes the system's own dismissal, a swipe down.
    func sync(
        _ isShowing: Bool,
        over presenter: StackRouter
    ) {
        guard !isShowing else {
            return
        }
        presenter.dismiss()
    }

    // Drops the level over `presenter` once its sheet or cover has gone.
    func release(over presenter: StackRouter) {
        levels[ObjectIdentifier(presenter)] = nil
    }

    func close() {
        onClose()
    }

    private func present(
        from level: SheetDemoLevel?,
        style: PresentationStyle
    ) {
        let presenter = level?.router ?? router
        let number = (level?.number ?? 0) + Self.firstLevel
        presenter.register(SheetDemoRoute.self)
        presenter.present(SheetDemoRoute(level: number), style: style)
        // A failed present, such as over a level that already presents one, leaves the old level.
        guard let presented = presenter.presented, presented !== self.level(over: presenter)?.router else {
            return
        }
        levels[ObjectIdentifier(presenter)] = SheetDemoLevel(
            router: presented,
            presenter: presenter,
            number: number,
            options: presenter.state.presentation.map { presenter.sheetOptions(for: $0) }
        )
    }
}
