//
//  StackRouter+ChildFlows.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// Starting child flows.
extension StackRouter {
    /// Presents the flow of `child`, a coordinator, above this stack. The child's router joins this
    /// router's tree, with any screens it already pushed, and the parent gets the flow's result in
    /// `onFinish` exactly once.
    ///
    /// ```swift
    /// router.present(CheckoutCoordinator(cart: cart), style: .sheet) { result in
    ///     // .finished(order), or .cancelled when the user swiped the sheet away
    /// }
    /// ```
    ///
    /// `onFinish` gets `.finished(value)` when the child calls `finish(with:)`, and `.cancelled`
    /// when the flow ends any other way: a swipe, a parent's dismiss, or another flow replacing
    /// it. It runs once the call that ended the flow is done. A present that returns `.failed`,
    /// or `.ignored`, started nothing, so `onFinish` is never called. A child whose router is
    /// this router or one above it fails with `childRouterIsAncestor`, and one whose router is
    /// already in another tree with `routerInAnotherTree`. Waypoint keeps the child until the
    /// flow ends, then lets it go.
    ///
    /// - Parameters:
    ///   - child: The coordinator of the presented flow.
    ///   - style: How the flow is presented. Default: `.sheet`.
    ///   - trigger: What in the screen started it, such as `checkout_button`, written in the
    ///     journey box. Default: `nil`.
    ///   - fallback: What to do if the presentation fails. Default: the flow's policy.
    ///   - file: The calling file, where an issue points. Leave the default.
    ///   - line: The calling line, where an issue points. Leave the default.
    ///   - onFinish: Gets the flow's result, once.
    @discardableResult
    public func present<Child: FlowCoordinating>(
        _ child: Child,
        style: PresentationStyle = .sheet,
        trigger: String? = nil,
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line,
        onFinish: @escaping @MainActor (FlowResult<Child.Output>) -> Void
    ) -> NavigationOutcome {
        present(style: style, trigger: trigger, else: fallback, file: file, line: line, onFinish: onFinish) {
            child
        }
    }

    /// Presents the flow of the coordinator `makeChild` returns, above this stack, building it only
    /// when the present happens.
    ///
    /// ```swift
    /// router.present(style: .sheet, onFinish: showOrder) {
    ///     CheckoutCoordinator(cart: cart)
    /// }
    /// ```
    ///
    /// A present that fails or is ignored never calls `makeChild`, and a queued one calls it when
    /// it runs. While `makeChild` runs, the child's router is made inside this router's tree, so
    /// a push in the child's `init` gets the tree's settings. Any other router made there stays
    /// separate, and one that took the child's place is reported as
    /// `routerDetachedFromLazyStart`. Otherwise this behaves as
    /// ``present(_:style:trigger:else:file:line:onFinish:)``.
    ///
    /// - Parameters:
    ///   - style: How the flow is presented. Default: `.sheet`.
    ///   - trigger: What in the screen started it, written in the journey box. Default: `nil`.
    ///   - fallback: What to do if the presentation fails. Default: the flow's policy.
    ///   - file: The calling file, where an issue points. Leave the default.
    ///   - line: The calling line, where an issue points. Leave the default.
    ///   - onFinish: Gets the flow's result, once.
    ///   - makeChild: Builds the coordinator of the presented flow.
    @discardableResult
    public func present<Child: FlowCoordinating>(
        style: PresentationStyle = .sheet,
        trigger: String? = nil,
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line,
        onFinish: @escaping @MainActor (FlowResult<Child.Output>) -> Void,
        _ makeChild: @escaping @MainActor () -> Child
    ) -> NavigationOutcome {
        let request = PresentationRequest { router, store in
            router.presentChildStep(style: style, file: file, line: line, in: store, onFinish: onFinish, makeChild)
        }
        return perform(
            file: file,
            line: line,
            fallback: fallback,
            presentation: request,
            trigger: trigger
        ) { router, store in
            request.step(router, store)
        }
    }
}
