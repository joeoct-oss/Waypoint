//
//  CoordinatorFixtures.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import WaypointCore
import WaypointTestSupport

/// A stack coordinator that takes every default.
///
/// Conformances:
/// - `StackCoordinating`, so the core makes, names and keeps its router.
@MainActor
final class ShopListCoordinator: StackCoordinating { }

/// A stack coordinator that makes its own router and registers the product route on it.
///
/// Conformances:
/// - `StackCoordinating`, so the core keeps the router `makeRouter()` makes.
@MainActor
final class OwnRouterCoordinator: StackCoordinating {
    /// The flow its router drives.
    static let flow = FlowID("ownRouter")

    /// The root name it declares, instead of its type's.
    var rootName: String {
        "Own list"
    }

    /// A router of the app's own, with a strict registry and a root name of its own, which the
    /// declared `rootName` replaces.
    func makeRouter() -> StackRouter {
        let router = StackRouter(flow: Self.flow)
        router.setRootName("Made list")
        return router
    }

    /// Registers the product route, so a push of one is applied.
    func registerDestinations(on router: StackRouter) {
        router.register(ProductRoute.self)
    }
}

/// A stack coordinator that stores the router it was given, as coordinators did before the
/// router table, and counts how often its destinations are registered.
///
/// Conformances:
/// - `StackCoordinating`, so the core checks the stored router when it touches the coordinator.
@MainActor
final class StoredRouterCoordinator: StackCoordinating {
    /// The router it was given.
    let router: StackRouter

    /// Each router its destinations were registered on.
    let registrations = Recorder<StackRouter>()

    /// Creates a coordinator that keeps `router`.
    init(router: StackRouter) {
        self.router = router
    }

    /// Registers the product route, and records the router.
    func registerDestinations(on router: StackRouter) {
        registrations.record(router)
        router.register(ProductRoute.self)
    }
}

/// A stack coordinator whose `init` makes another coordinator and reads both routers.
///
/// Conformances:
/// - `StackCoordinating`, so the core makes its router.
@MainActor
final class OuterCoordinator: StackCoordinating {
    /// The coordinator it made in `init`.
    let inner: ShopListCoordinator

    /// The inner coordinator's router, read in `init`.
    let innerRouter: StackRouter

    /// Creates the inner coordinator and reads its router, then this one's.
    init() {
        let inner = ShopListCoordinator()
        self.inner = inner
        self.innerRouter = inner.router
        _ = router
    }
}

/// A stack coordinator that reads its router in `deinit` and records what a push there did.
///
/// Conformances:
/// - `StackCoordinating`, so the core makes its router, or stands in for it in `deinit`.
@MainActor
final class DeinitReadingCoordinator: StackCoordinating {
    /// What the push in `deinit` returned, and the router it went to.
    let outcomes: Recorder<(NavigationOutcome, StackRouter)>

    /// The router `makeRouter()` returns, or `nil` for a new one.
    let madeRouter: StackRouter?

    /// Creates a coordinator that records into `outcomes`.
    init(outcomes: Recorder<(NavigationOutcome, StackRouter)>, madeRouter: StackRouter? = nil) {
        self.outcomes = outcomes
        self.madeRouter = madeRouter
    }

    /// Pushes from `deinit`, where the coordinator is going away. The tests free it on the main
    /// actor. `MainActor.assumeIsolated` instead of `isolated deinit`, which needs a newer OS
    /// than the package's minimum.
    deinit {
        MainActor.assumeIsolated {
            let router = router
            outcomes.record((router.push(ProductRoute(id: 1)), router))
        }
    }

    /// The given router, or a permissive one.
    func makeRouter() -> StackRouter {
        madeRouter ?? StackRouter(configuration: .permissive)
    }
}

/// A stack coordinator whose `makeRouter()` returns a router it was given, such as a parent's.
///
/// Conformances:
/// - `StackCoordinating`, so the core checks the router `makeRouter()` returns.
@MainActor
final class GivenRouterCoordinator: StackCoordinating {
    /// The router `makeRouter()` returns.
    let given: StackRouter

    /// Creates a coordinator whose `makeRouter()` returns `given`.
    init(given: StackRouter) {
        self.given = given
    }

    /// The router it was given.
    func makeRouter() -> StackRouter {
        given
    }
}

/// A stack coordinator whose `makeRouter()` names the root screen and keeps the default
/// `rootName`.
///
/// Conformances:
/// - `StackCoordinating`, so the core keeps the name its router came with.
@MainActor
final class NamedRouterCoordinator: StackCoordinating {
    /// A router whose root screen is named `Made list`.
    func makeRouter() -> StackRouter {
        let router = StackRouter()
        router.setRootName("Made list")
        return router
    }
}

/// A stack coordinator that declares the same root name as its default, and whose `makeRouter()`
/// names the root screen.
///
/// Conformances:
/// - `StackCoordinating`, so the core names its router.
@MainActor
final class SameNameCoordinator: StackCoordinating {
    /// The same name the type would get by default.
    var rootName: String {
        "SameName"
    }

    /// A router whose root screen is named `Made list`.
    func makeRouter() -> StackRouter {
        let router = StackRouter()
        router.setRootName("Made list")
        return router
    }
}

/// A stack coordinator whose router takes any route, so a test can present without registering.
///
/// Conformances:
/// - `StackCoordinating`, so the core makes and keeps its router.
@MainActor
final class PermissiveCoordinator: StackCoordinating {
    /// A router with a permissive registry.
    func makeRouter() -> StackRouter {
        StackRouter(configuration: .permissive)
    }
}
