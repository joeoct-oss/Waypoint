//
//  StackCoordinator.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// App code that owns one stack flow.
///
/// Conforming fills in the router, as `StackCoordinating` describes: made the
/// first time it is read, named after the coordinator, and released once the coordinator is
/// gone. Draw it with `WaypointStack(router: coordinator.router)` for now; the coordinator's own
/// `root`, `destinations` and `view` come later in #59.
///
/// ```swift
/// final class ShopCoordinator: StackCoordinator {
///     func showProduct(_ id: Int) {
///         router.push(ProductRoute(id: id))
///     }
/// }
/// ```
///
/// Conformances:
/// - `StackCoordinating`, the core protocol with the router and its defaults, which has no UI so
///   a coordinator's logic is tested on Linux.
@MainActor
public protocol StackCoordinator: StackCoordinating { }
