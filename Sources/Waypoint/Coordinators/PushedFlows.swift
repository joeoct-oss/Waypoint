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
    /// type while its push is still animating returns `.alreadyThere`. Give the child route types
    /// of its own: the screens below it share one stack, and SwiftUI draws a route type with the
    /// destination nearest the stack's root, so a type the parent also shows draws the parent's
    /// screen, on the parent's router. The child's own `Renderer`
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

    /// Pushes the flow of `child`, a coordinator, on this stack, and returns the flow's result
    /// once it ends.
    ///
    /// ```swift
    /// if case .finished(let review) = await router.push(ReviewCoordinator(product: product)) {
    ///     showThanks(for: review)
    /// }
    /// ```
    ///
    /// It returns what ``push(_:trigger:else:file:line:onFinish:)`` would give its `onFinish`:
    /// `.finished(value)` when the child finishes, and `.cancelled` when the user goes back past
    /// its first screen or this router changes its own path. A push that fails, is ignored or is
    /// skipped as a double tap returns `.cancelled` at once. Cancelling the awaiting task returns
    /// `.cancelled` at once and leaves the flow up, as for
    /// `present(_:style:trigger:else:file:line:)`. A screen's `.task` is cancelled when the
    /// pushed screen hides it, so await from the coordinator, and use the `onFinish:` form from a
    /// screen.
    ///
    /// - Parameters:
    ///   - child: The coordinator of the pushed flow.
    ///   - trigger: What in the screen started it, written in the journey box. Default: `nil`.
    ///   - fallback: What to do if the push fails. Default: the flow's policy.
    ///   - file: The calling file, where an issue points. Leave the default.
    ///   - line: The calling line, where an issue points. Leave the default.
    /// - Returns: The flow's result, once it ends, or `.cancelled` when it never started.
    public func push<Child: FlowCoordinator>(
        _ child: Child,
        trigger: String? = nil,
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) async -> FlowResult<Child.Output> {
        await pushFlow(trigger: trigger, else: fallback, file: file, line: line) {
            child
        }
    }

    /// Pushes the flow of the coordinator `makeChild` returns on this stack, building it only
    /// when the push happens, and returns the flow's result once it ends. A push that is refused
    /// or skipped builds nothing and returns `.cancelled` at once. Otherwise this behaves as
    /// ``push(_:trigger:else:file:line:)``.
    ///
    /// - Parameters:
    ///   - trigger: What in the screen started it, written in the journey box. Default: `nil`.
    ///   - fallback: What to do if the push fails. Default: the flow's policy.
    ///   - file: The calling file, where an issue points. Leave the default.
    ///   - line: The calling line, where an issue points. Leave the default.
    ///   - makeChild: Builds the coordinator of the pushed flow.
    /// - Returns: The flow's result, once it ends, or `.cancelled` when it never started.
    public func push<Child: FlowCoordinator>(
        trigger: String? = nil,
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line,
        _ makeChild: @escaping @MainActor () -> Child
    ) async -> FlowResult<Child.Output> {
        await pushFlow(trigger: trigger, else: fallback, file: file, line: line, makeChild)
    }
}
