//
//  FlowRouters.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// Not guarded by `canImport(SwiftUI)`: it uses only the core, so its rules are unit tested on
// Linux too. The environment entry that carries it is in `NavigationEnvironment.swift`.

import WaypointCore

/// The nearest stack of each declared flow above a view, which `@FlowNavigation` reads.
///
/// Each ``WaypointStack`` adds its router when the router was declared for a flow, so a stack
/// inside another stack of the same flow wins, and a sheet drawn inside a stack still finds it.
///
/// Conformances:
/// - `Sendable`, because SwiftUI keeps environment values in a `Sendable` store.
struct FlowRouters: Sendable {
    /// The nearest declared router of each flow, by the flow type's identifier.
    private let routers: [ObjectIdentifier: StackRouter]

    /// No stacks.
    init() {
        self.routers = [:]
    }

    /// A map with these routers.
    private init(routers: [ObjectIdentifier: StackRouter]) {
        self.routers = routers
    }

    /// The nearest stack declared for `flow`, or `nil`.
    @MainActor
    func router<Flow: NavigationFlow>(for flow: Flow.Type) -> StackRouter? {
        routers[ObjectIdentifier(flow)]
    }

    /// This map with `router` as the nearest stack of its declared flow. A router declared for
    /// no flow changes nothing.
    @MainActor
    func adding(_ router: StackRouter) -> FlowRouters {
        guard let flow = router.declaredFlow else {
            return self
        }
        let nearest = [ObjectIdentifier(flow): router]
        let updated = routers.merging(nearest) { _, inner in
            inner
        }
        return FlowRouters(routers: updated)
    }
}
