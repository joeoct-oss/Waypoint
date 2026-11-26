//
//  AwaitedChildFlows.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// Starting child flows and awaiting their results.
extension StackRouter {
    /// Presents the flow of `child`, a coordinator, above this stack, and returns the flow's
    /// result once it ends.
    ///
    /// ```swift
    /// switch await router.present(SignInCoordinator(), style: .sheet) {
    /// case .finished(let account):
    ///     continueAs(account)
    /// case .cancelled:
    ///     break
    /// }
    /// ```
    ///
    /// It returns what ``present(_:style:trigger:else:file:line:onFinish:)`` would give its
    /// `onFinish`: `.finished(value)` when the child calls `finish(with:)`, and `.cancelled` when
    /// the flow ends any other way. It never waits for a flow that didn't start: a present that
    /// fails, is ignored, or whose fallback started no flow returns `.cancelled` at once. The
    /// refusal is still reported and logged, and the `onFinish:` form returns its outcome.
    ///
    /// Cancelling the task that awaits returns `.cancelled` at once and leaves the flow up, since
    /// SwiftUI cancels a screen's `.task` when another screen hides it. When the flow ends later,
    /// it is dismissed and released as usual, and its result is logged at debug level as not
    /// delivered. So await from a coordinator or a task the app keeps, and use the `onFinish:`
    /// form from a screen.
    ///
    /// - Parameters:
    ///   - child: The coordinator of the presented flow.
    ///   - style: How the flow is presented. Default: `.sheet`.
    ///   - trigger: What in the screen started it, such as `sign_in_button`, written in the
    ///     journey box. Default: `nil`.
    ///   - fallback: What to do if the presentation fails. Default: the flow's policy.
    ///   - file: The calling file, where an issue points. Leave the default.
    ///   - line: The calling line, where an issue points. Leave the default.
    /// - Returns: The flow's result, once it ends, or `.cancelled` when it never started.
    public func present<Child: FlowCoordinating>(
        _ child: Child,
        style: PresentationStyle = .sheet,
        trigger: String? = nil,
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) async -> FlowResult<Child.Output> {
        await present(style: style, trigger: trigger, else: fallback, file: file, line: line) {
            child
        }
    }

    /// Presents the flow of the coordinator `makeChild` returns, above this stack, building it
    /// only when the present happens, and returns the flow's result once it ends.
    ///
    /// ```swift
    /// let result = await router.present(style: .sheet) {
    ///     SignInCoordinator(services: services)
    /// }
    /// ```
    ///
    /// A present that fails or is ignored never calls `makeChild` and returns `.cancelled` at
    /// once. Otherwise this behaves as ``present(_:style:trigger:else:file:line:)``, and
    /// `makeChild` runs as in ``present(style:trigger:else:file:line:onFinish:_:)``.
    ///
    /// - Parameters:
    ///   - style: How the flow is presented. Default: `.sheet`.
    ///   - trigger: What in the screen started it, written in the journey box. Default: `nil`.
    ///   - fallback: What to do if the presentation fails. Default: the flow's policy.
    ///   - file: The calling file, where an issue points. Leave the default.
    ///   - line: The calling line, where an issue points. Leave the default.
    ///   - makeChild: Builds the coordinator of the presented flow.
    /// - Returns: The flow's result, once it ends, or `.cancelled` when it never started.
    public func present<Child: FlowCoordinating>(
        style: PresentationStyle = .sheet,
        trigger: String? = nil,
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line,
        _ makeChild: @escaping @MainActor () -> Child
    ) async -> FlowResult<Child.Output> {
        await awaitResult(of: Child.self, file: file, line: line) { onFinish in
            present(
                style: style,
                trigger: trigger,
                else: fallback,
                file: file,
                line: line,
                onFinish: onFinish,
                makeChild
            )
        }
    }

    /// Pushes the flow of the coordinator `makeChild` returns on this stack, and returns the
    /// flow's result once it ends. `package`: apps push with `Waypoint`'s `await` forms, which
    /// take a `FlowCoordinator`, whose screens a renderer can draw.
    ///
    /// A push that fails, is ignored or is skipped as a double tap returns `.cancelled` at once.
    /// Cancelling the awaiting task behaves as for ``present(_:style:trigger:else:file:line:)``.
    package func pushFlow<Child: FlowCoordinating>(
        trigger: String?,
        else fallback: NavigationFallback?,
        file: StaticString,
        line: UInt,
        _ makeChild: @escaping @MainActor () -> Child
    ) async -> FlowResult<Child.Output> {
        await awaitResult(of: Child.self, file: file, line: line) { onFinish in
            pushFlow(trigger: trigger, else: fallback, file: file, line: line, onFinish: onFinish, makeChild)
        }
    }
}

/// Starting child flows above a tab container and awaiting their results.
extension TabRouter {
    /// Presents the flow of `child`, a coordinator, above the whole tab container, and returns
    /// the flow's result once it ends, as ``StackRouter/present(_:style:trigger:else:file:line:)``
    /// does above a stack.
    ///
    /// - Parameters:
    ///   - child: The coordinator of the presented flow.
    ///   - style: How the flow is presented. Default: `.sheet`.
    ///   - trigger: What started it, written in the journey box. Default: `nil`.
    ///   - fallback: What to do if the presentation fails. Default: the flow's policy.
    ///   - file: The calling file, where an issue points. Leave the default.
    ///   - line: The calling line, where an issue points. Leave the default.
    /// - Returns: The flow's result, once it ends, or `.cancelled` when it never started.
    public func present<Child: FlowCoordinating>(
        _ child: Child,
        style: PresentationStyle = .sheet,
        trigger: String? = nil,
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) async -> FlowResult<Child.Output> {
        await present(style: style, trigger: trigger, else: fallback, file: file, line: line) {
            child
        }
    }

    /// Presents the flow of the coordinator `makeChild` returns, above the whole tab container,
    /// building it only when the present happens, and returns the flow's result once it ends, as
    /// ``StackRouter/present(style:trigger:else:file:line:_:)`` does above a stack.
    ///
    /// - Parameters:
    ///   - style: How the flow is presented. Default: `.sheet`.
    ///   - trigger: What started it, written in the journey box. Default: `nil`.
    ///   - fallback: What to do if the presentation fails. Default: the flow's policy.
    ///   - file: The calling file, where an issue points. Leave the default.
    ///   - line: The calling line, where an issue points. Leave the default.
    ///   - makeChild: Builds the coordinator of the presented flow.
    /// - Returns: The flow's result, once it ends, or `.cancelled` when it never started.
    public func present<Child: FlowCoordinating>(
        style: PresentationStyle = .sheet,
        trigger: String? = nil,
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line,
        _ makeChild: @escaping @MainActor () -> Child
    ) async -> FlowResult<Child.Output> {
        await awaitResult(of: Child.self, file: file, line: line) { onFinish in
            present(
                style: style,
                trigger: trigger,
                else: fallback,
                file: file,
                line: line,
                onFinish: onFinish,
                makeChild
            )
        }
    }
}
