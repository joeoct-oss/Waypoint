//
//  PushedFlows.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// Pushing a child flow is public here, not in `WaypointCore`, because a pushed flow's screens are
// drawn on its parent's stack: only a `FlowCoordinator`, which has a `root` and `destinations`,
// can be pushed, which the compiler checks.

extension StackRouter {
    /// Pushes the flow of `child`, a coordinator, on this stack.
    ///
    /// The child's screens follow on the same stack: its `root` screen first, then each screen its
    /// router pushes, drawn from its `destinations`. The child's router joins this router's tree,
    /// and the parent gets the flow's result in `onFinish` exactly once.
    ///
    /// ```swift
    /// router.push(ReviewCoordinator(product: product)) { result in
    ///     // .finished(review), or .cancelled when the user went back past its first screen
    /// }
    /// ```
    ///
    /// The flow ends with `.cancelled` when the user goes back past its root screen, or when this
    /// router changes its own path: a push, a pop or a `popTo` here ends the child on top first.
    /// `finish(with:)` and `dismissFlow()` in the child pop back to the screen below its root
    /// screen. Under `DuplicatePushRule.skipWhileInFlight`, a second push of the same coordinator
    /// type while its push is still animating returns `.alreadyThere`. The child's own `Renderer`
    /// is not used: its parent's stack draws it. A child that needs a stack of its own is
    /// presented with `present(_:style:onFinish:)`. Refusals are as for a
    /// present.
    ///
    /// - Parameters:
    ///   - child: The coordinator of the pushed flow.
    ///   - trigger: What in the screen started it, written in the journey box. Default: `nil`.
    ///   - fallback: What to do if the push fails. Default: the flow's policy.
    ///   - file: The calling file, where an issue points. Leave the default.
    ///   - line: The calling line, where an issue points. Leave the default.
    ///   - onFinish: Gets the flow's result, once.
    @discardableResult
    public func push<Child: FlowCoordinator>(
        _ child: Child,
        trigger: String? = nil,
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line,
        onFinish: @escaping @MainActor (FlowResult<Child.Output>) -> Void
    ) -> NavigationOutcome {
        pushFlow(trigger: trigger, else: fallback, file: file, line: line, onFinish: onFinish) {
            child
        }
    }

    /// Pushes the flow of the coordinator `makeChild` returns on this stack, building it only when
    /// the push happens, so a push that is refused or skipped builds nothing. Otherwise this
    /// behaves as ``push(_:trigger:else:file:line:onFinish:)``.
    ///
    /// ```swift
    /// router.push(onFinish: { self.reviewEnded($0) }) {
    ///     ReviewCoordinator(product: product)
    /// }
    /// ```
    ///
    /// `makeChild` runs inside this router's tree, so a push from the child's `init` gets the
    /// tree's settings.
    ///
    /// - Parameters:
    ///   - trigger: What in the screen started it, written in the journey box. Default: `nil`.
    ///   - fallback: What to do if the push fails. Default: the flow's policy.
    ///   - file: The calling file, where an issue points. Leave the default.
    ///   - line: The calling line, where an issue points. Leave the default.
    ///   - onFinish: Gets the flow's result, once.
    ///   - makeChild: Builds the coordinator of the pushed flow.
    @discardableResult
    public func push<Child: FlowCoordinator>(
        trigger: String? = nil,
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line,
        onFinish: @escaping @MainActor (FlowResult<Child.Output>) -> Void,
        _ makeChild: @escaping @MainActor () -> Child
    ) -> NavigationOutcome {
        pushFlow(trigger: trigger, else: fallback, file: file, line: line, onFinish: onFinish, makeChild)
    }
}
