//
//  ChildFlowFixtures.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Understudy
import WaypointCore
import WaypointTestSupport

/// A child flow that ends with an order number and registers the product route.
///
/// Conformances:
/// - `FlowCoordinating`, so a parent can start it and get its result.
@MainActor
final class CheckoutFlowCoordinator: FlowCoordinating {
    /// The order number it finishes with.
    typealias Output = String

    /// Registers the product route, so a push of one is applied.
    func registerDestinations(on router: StackRouter) {
        router.register(ProductRoute.self)
    }
}

/// A child flow whose `init` pushes a product it registers nowhere, so the push only works in a
/// tree with a permissive registry.
///
/// Conformances:
/// - `FlowCoordinating`, so a parent can start it.
@MainActor
final class PushingInInitFlowCoordinator: FlowCoordinating {
    /// It finishes with nothing.
    typealias Output = Int

    /// What the push in `init` returned.
    let outcomes = Spy<NavigationOutcome, Void>()

    /// Creates the flow and pushes a product on its router.
    init() {
        outcomes(router.push(ProductRoute(id: 1)))
    }
}

/// A child flow whose `makeRouter()` returns a permissive router of its own, and whose `init`
/// pushes a product on it.
///
/// Conformances:
/// - `FlowCoordinating`, so a parent can start it.
@MainActor
final class OwnRouterFlowCoordinator: FlowCoordinating {
    /// It finishes with nothing.
    typealias Output = Int

    /// What the push in `init` returned.
    let outcomes = Spy<NavigationOutcome, Void>()

    /// Creates the flow and pushes a product on its router.
    init() {
        outcomes(router.push(ProductRoute(id: 1)))
    }

    /// A router of its own, with a permissive registry.
    func makeRouter() -> StackRouter {
        StackRouter(configuration: .permissive)
    }
}

/// A child flow whose `makeRouter()` returns a router it was given, such as a parent's.
///
/// Conformances:
/// - `FlowCoordinating`, so a parent can try to start it.
@MainActor
final class GivenRouterFlowCoordinator: FlowCoordinating {
    /// It finishes with nothing.
    typealias Output = Int

    /// The router `makeRouter()` returns.
    let given: StackRouter

    /// Creates a flow whose `makeRouter()` returns `given`.
    init(given: StackRouter) {
        self.given = given
    }

    /// The router it was given.
    func makeRouter() -> StackRouter {
        given
    }
}

/// A child flow whose `init` can make another flow of its own type and read that one's router
/// first, and can read its own router.
///
/// Conformances:
/// - `FlowCoordinating`, so a parent can start it.
@MainActor
final class TwinMakingFlowCoordinator: FlowCoordinating {
    /// It finishes with nothing.
    typealias Output = Int

    /// The other flow it made in `init`, if any.
    let twin: TwinMakingFlowCoordinator?

    /// Creates the flow. With `makingTwin`, it first makes another one and reads its router.
    init(makingTwin: Bool) {
        twin = makingTwin ? TwinMakingFlowCoordinator(makingTwin: false) : nil
        _ = twin?.router
        _ = router
    }
}

/// A child flow whose `init` makes a stack coordinator of another type and reads its router.
///
/// Conformances:
/// - `FlowCoordinating`, so a parent can start it.
@MainActor
final class InnerMakingFlowCoordinator: FlowCoordinating {
    /// It finishes with nothing.
    typealias Output = Int

    /// The coordinator it made in `init`.
    let inner: ShopListCoordinator

    /// Creates the flow, then the inner coordinator, and reads both routers.
    init() {
        inner = ShopListCoordinator()
        _ = inner.router
        _ = router
    }
}

/// A child flow that can read its router in `init`, and reads it in `deinit`.
///
/// Conformances:
/// - `FlowCoordinating`, so a parent can start it.
@MainActor
final class DyingFlowCoordinator: FlowCoordinating {
    /// It finishes with nothing.
    typealias Output = Int

    /// Each router `deinit` read.
    let deinitRouters: Spy<StackRouter, Void>

    /// Creates the flow. With `readingRouter`, it reads its router in `init`.
    init(deinitRouters: Spy<StackRouter, Void>, readingRouter: Bool) {
        self.deinitRouters = deinitRouters
        if readingRouter {
            _ = router
        }
    }

    /// Reads the router from `deinit`. The tests free it on the main actor.
    deinit {
        MainActor.assumeIsolated {
            deinitRouters(router)
        }
    }
}

/// A child flow whose `init` lazily starts a flow on another router, in another tree.
///
/// Conformances:
/// - `FlowCoordinating`, so a parent can start it.
@MainActor
final class StartingFlowCoordinator: FlowCoordinating {
    /// It finishes with nothing.
    typealias Output = Int

    /// The flow it started on the other router.
    let started: Spy<CheckoutFlowCoordinator, Void>

    /// Reads its router, then starts a checkout flow on `other`.
    init(startingOn other: StackRouter) {
        let started = Spy<CheckoutFlowCoordinator, Void>()
        self.started = started
        _ = router
        other.present(onFinish: { _ in }) {
            let child = CheckoutFlowCoordinator()
            started(child)
            _ = child.router
            return child
        }
    }
}
