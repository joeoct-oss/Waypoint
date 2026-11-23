//
//  FlowCoordinating.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// How a child flow ended: with the value it finished with, or cancelled.
///
/// A parent gets it exactly once for each child flow it started, in the `onFinish:` of
/// ``StackRouter/present(_:style:trigger:else:file:line:onFinish:)``. Pushing a flow on the
/// parent's stack comes once renderers draw pushed flows.
///
/// `Value` is `Sendable` because the result is `Sendable`, so the value it carries must be too.
///
/// Conformances:
/// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
public enum FlowResult<Value: Sendable>: Sendable {
    /// The flow called `finish(with:)` with this value.
    case finished(Value)
    /// The flow ended without a value: the user swiped it away, a parent dismissed it, or another
    /// flow replaced it.
    case cancelled
}

/// Conformances:
/// - `Equatable` when the value is, so tests can compare results.
extension FlowResult: Equatable where Value: Equatable { }

/// Code that owns one stack flow that ends with a result, without its screens.
///
/// Apps write `FlowCoordinator` from the `Waypoint` product, which refines this protocol. A parent
/// starts the flow with `router.present(child, onFinish:)` (or pushes it on its stack, once
/// renderers draw pushed flows); the child's router joins the parent's tree, and the child ends
/// the flow with ``finish(with:)``:
///
/// ```swift
/// final class CheckoutCoordinator: FlowCoordinating {
///     typealias Output = Order
///
///     func placeOrder(_ order: Order) {
///         finish(with: order)
///     }
/// }
///
/// router.present(CheckoutCoordinator(), style: .sheet) { result in
///     // .finished(order), or .cancelled when the user swiped the sheet away
/// }
/// ```
///
/// Conformances:
/// - `StackCoordinating`, because a flow is a stack with a router of its own.
@MainActor
public protocol FlowCoordinating: StackCoordinating {
    /// The value the flow finishes with.
    associatedtype Output: Sendable

    /// Ends the flow with `output`: the parent's `onFinish:` gets `.finished(output)`, and the
    /// flow is dismissed. Default: does both, then Waypoint releases the flow's router and lets
    /// the coordinator go. A second call, or a dismiss that wins first, delivers nothing more.
    func finish(with output: Output)
}

extension FlowCoordinating {
    /// Keeps `output` for the parent, then dismisses the flow.
    public func finish(with output: Output) {
        RouterTable.shared.finish(self, with: output)
    }
}
