//
//  FlowCoordinator.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// App code that owns one stack flow that ends with a result, such as checkout or sign in.
///
/// A parent starts it with `router.present(child) { result in … }`, or pushes it on its own stack
/// with `router.push(child) { result in … }`, and the flow ends it with `finish(with:)`.
/// Conforming fills in the router, as `StackCoordinator` does, and `finish(with:)`, as
/// `FlowCoordinating` describes: the parent gets `.finished(value)`, the flow is dismissed, and
/// Waypoint lets the coordinator go. Like a `StackCoordinator`, it writes its `root` and
/// `destinations`, and Waypoint fills in `view`.
///
/// ```swift
/// final class CheckoutCoordinator: FlowCoordinator {
///     typealias Output = Order
///
///     var root: some View {
///         CartReviewView(onPlaceOrder: { self.placeOrder($0) })
///     }
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
