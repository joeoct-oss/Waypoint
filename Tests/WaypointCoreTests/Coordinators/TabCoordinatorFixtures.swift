//
//  TabCoordinatorFixtures.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Understudy
import WaypointTestSupport

@testable import WaypointCore

/// A tab coordinator over `MainTab` whose children a test chooses, and which records the tabs it
/// is asked for and the issues its tree reports.
///
/// Conformances:
/// - `TabCoordinating`, so the core makes its router and asks it for each tab's child.
@MainActor
final class MainTabsCoordinator: TabCoordinating {
    /// Makes the child of one tab. It gets the tab coordinator to read, never to keep strongly.
    typealias ChildMaker = @MainActor (MainTab, MainTabsCoordinator) -> any StackCoordinating

    /// The tabs its router starts with.
    let tabs: [MainTab]

    /// The tab selected at the start.
    let selection: MainTab

    /// Where the tabs' pushed screens go.
    let stacks: TabStacks

    /// Each tab it was asked for, in order.
    let asked = Spy<MainTab, Void>()

    /// Each issue its tree reported.
    let reported = Spy<NavigationIssue, Void>()

    /// Makes each tab's child.
    private let makeChild: ChildMaker

    /// The kinds of the issues its tree reported.
    var reportedKinds: [NavigationIssue.Kind] {
        reported.calls.map(\.kind)
    }

    /// Creates a tab coordinator. Default: every tab, `home` selected, a stack per tab, and a
    /// plain child for each tab.
    init(
        tabs: [MainTab] = MainTab.allCases,
        selection: MainTab = .home,
        stacks: TabStacks = .perTab,
        makeChild: @escaping ChildMaker = { _, _ in TabChildCoordinator() }
    ) {
        self.tabs = tabs
        self.selection = selection
        self.stacks = stacks
        self.makeChild = makeChild
    }

    /// Creates a tab coordinator whose `tab` gets the child `make` makes, and every other tab a
    /// plain child.
    convenience init(
        selection: MainTab = .home,
        stacks: TabStacks = .perTab,
        giving tab: MainTab,
        _ make: @escaping @MainActor () -> any StackCoordinating
    ) {
        self.init(selection: selection, stacks: stacks) { asked, _ in
            asked == tab ? make() : TabChildCoordinator()
        }
    }

    /// A permissive tab router whose reports are recorded.
    func makeRouter() -> TabRouter<MainTab> {
        let router = TabRouter(tabs: tabs, selection: selection, stacks: stacks, configuration: .permissive)
        router.tree.onReported { [reported] issue in
            reported(issue)
        }
        return router
    }

    /// The child the test chose, recording the tab.
    func coordinator(for tab: MainTab) -> any StackCoordinating {
        asked(tab)
        return makeChild(tab, self)
    }
}

/// A tab's child that takes every default.
///
/// Conformances:
/// - `StackCoordinating`, so the core makes its router, which becomes its tab's stack.
@MainActor
final class TabChildCoordinator: StackCoordinating { }

/// A tab's child that declares its root name.
///
/// Conformances:
/// - `StackCoordinating`, so the core makes its router and names its root screen.
@MainActor
final class NamedTabChildCoordinator: StackCoordinating {
    /// The root name it declares.
    var rootName: String {
        "Deals"
    }
}

/// A tab's child that pushes on its own permissive router in `init`, before it joins its tab.
///
/// Conformances:
/// - `StackCoordinating`, so the core makes its router.
@MainActor
final class EarlyPushCoordinator: StackCoordinating {
    /// The navigator of its root screen, taken in `init` before the push.
    let rootNavigator: StackNavigator

    /// The router made in `init`.
    let made: StackRouter

    /// Takes the root screen's navigator, then pushes product 1.
    init() {
        let router = StackRouter(configuration: .permissive)
        rootNavigator = router.navigator
        made = router
        router.push(ProductRoute(id: 1))
    }

    /// The router made in `init`, already holding a pushed screen.
    func makeRouter() -> StackRouter {
        made
    }
}

/// A tab's child that reads its tab coordinator's router in `init`, and takes the navigator of
/// its tab's stack from it.
///
/// Conformances:
/// - `StackCoordinating`, so the core makes its router.
@MainActor
final class ParentReadingCoordinator: StackCoordinating {
    /// The tab router it read in `init`.
    let parentRouter: TabRouter<MainTab>

    /// The navigator of its tab's stack, taken from the tab router in `init`.
    let tabNavigator: StackNavigator

    /// Reads `parent`'s router, without keeping `parent`.
    init(tab: MainTab, parent: MainTabsCoordinator) {
        parentRouter = parent.router
        tabNavigator = parent.router.router(for: tab).navigator
    }
}

/// A tab coordinator that reads its router in `deinit` and records what a select there did.
///
/// Conformances:
/// - `TabCoordinating`, so the core makes its router, or stands in for it in `deinit`.
@MainActor
final class DeinitReadingTabsCoordinator: TabCoordinating {
    /// What the select in `deinit` returned, and the router it went to.
    let outcomes: Spy<(NavigationOutcome, TabRouter<MainTab>), Void>

    /// Creates a coordinator that records into `outcomes`.
    init(outcomes: Spy<(NavigationOutcome, TabRouter<MainTab>), Void>) {
        self.outcomes = outcomes
    }

    /// Selects a tab from `deinit`, where the coordinator is going away.
    deinit {
        MainActor.assumeIsolated {
            let router = router
            outcomes((router.select(.shop), router))
        }
    }

    /// Every tab, `home` selected.
    func makeRouter() -> TabRouter<MainTab> {
        TabRouter(tabs: MainTab.allCases, selection: .home, configuration: .permissive)
    }

    /// A plain child.
    func coordinator(for tab: MainTab) -> any StackCoordinating {
        TabChildCoordinator()
    }
}

/// Hands out one child until it is freed, so a tab coordinator returns it for two tabs without
/// the maker keeping it alive.
@MainActor
final class ReusedChildMaker {
    /// The child handed out, held weakly so only the tab coordinator keeps it.
    ///
    /// `var` because the first call makes the child. Only ``make()`` changes it.
    private(set) weak var child: TabChildCoordinator?

    /// The child handed out before, or a new one.
    func make() -> TabChildCoordinator {
        if let child {
            return child
        }
        let made = TabChildCoordinator()
        child = made
        return made
    }
}

/// A tab coordinator that stores its tab router, as coordinators did before the router table.
///
/// Conformances:
/// - `TabCoordinating`, so the core checks the stored router when it touches the coordinator.
@MainActor
final class StoredTabsCoordinator: TabCoordinating {
    /// The router it stores.
    let router: TabRouter<MainTab>

    /// Each tab it was asked for, in order.
    let asked = Spy<MainTab, Void>()

    /// Creates a coordinator that keeps `router`.
    init(router: TabRouter<MainTab>) {
        self.router = router
    }

    /// Never called while `router` is stored; a new router of every tab.
    func makeRouter() -> TabRouter<MainTab> {
        TabRouter(tabs: MainTab.allCases, selection: .home)
    }

    /// A plain child, recording the tab.
    func coordinator(for tab: MainTab) -> any StackCoordinating {
        asked(tab)
        return TabChildCoordinator()
    }
}

/// A tab coordinator whose `makeRouter()` returns a tab router it was given, such as another tab
/// coordinator's.
///
/// Conformances:
/// - `TabCoordinating`, so the core checks the router `makeRouter()` returns.
@MainActor
final class GivenTabsCoordinator: TabCoordinating {
    /// The router `makeRouter()` returns.
    let given: TabRouter<MainTab>

    /// Each tab it was asked for, in order.
    let asked = Spy<MainTab, Void>()

    /// Creates a coordinator whose `makeRouter()` returns `given`.
    init(given: TabRouter<MainTab>) {
        self.given = given
    }

    /// The router it was given.
    func makeRouter() -> TabRouter<MainTab> {
        given
    }

    /// A plain child, recording the tab.
    func coordinator(for tab: MainTab) -> any StackCoordinating {
        asked(tab)
        return TabChildCoordinator()
    }
}

/// A tab's child that presents a flow on its own permissive router in `init`, before it joins
/// its tab.
///
/// Conformances:
/// - `StackCoordinating`, so the core makes its router.
@MainActor
final class EarlyPresentCoordinator: StackCoordinating {
    /// The router made in `init`.
    let made: StackRouter

    /// The flow presented in `init`.
    let presentedFlow: StackRouter?

    /// Presents the cart on a new router.
    init() {
        let router = StackRouter(configuration: .permissive)
        router.present(CartRoute())
        made = router
        presentedFlow = router.presented
    }

    /// The router made in `init`, already presenting a flow.
    func makeRouter() -> StackRouter {
        made
    }
}
