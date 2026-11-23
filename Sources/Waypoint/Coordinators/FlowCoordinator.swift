//
//  FlowCoordinator.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// App code that owns one stack flow that ends with a result, such as checkout or sign in.
///
/// A parent starts it with `router.present(child) { result in … }`, and the flow ends it with
/// `finish(with:)`. Conforming fills in the router, as `StackCoordinator` does, and
/// `finish(with:)`, as `FlowCoordinating` describes: the parent gets `.finished(value)`, the flow
/// is dismissed, and Waypoint lets the coordinator go. Its own `root`, `destinations` and `view`
/// come later in #59.
///
/// ```swift
/// final class CheckoutCoordinator: FlowCoordinator {
///     typealias Output = Order
///
///     func placeOrder(_ order: Order) {
///         finish(with: order)
///     }
/// }
/// ```
///
/// Conformances:
/// - `StackCoordinator`, because a flow is a stack with a router of its own.
/// - `FlowCoordinating`, the core protocol with the result and its defaults, which has no UI so
///   a flow's logic is tested on Linux.
@MainActor
public protocol FlowCoordinator: StackCoordinator, FlowCoordinating { }
