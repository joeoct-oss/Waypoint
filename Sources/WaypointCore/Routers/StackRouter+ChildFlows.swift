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

    /// Pushes the flow of `child`, a coordinator, on this stack. The child's screens follow on
    /// the same stack: the child's root screen first, then each screen its router pushes. The
    /// child's router joins this router's tree, and the parent gets the flow's result in
    /// `onFinish` exactly once.
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
    /// screen. Under ``DuplicatePushRule/skipWhileInFlight``, a push of the same coordinator type
    /// while its push is still animating returns `.alreadyThere`. A child that needs a stack of
    /// its own is presented with ``present(_:style:trigger:else:file:line:onFinish:)``. Refusals
    /// are as for a present.
    ///
    /// - Parameters:
    ///   - child: The coordinator of the pushed flow.
    ///   - trigger: What in the screen started it, written in the journey box. Default: `nil`.
    ///   - fallback: What to do if the push fails. Default: the flow's policy.
    ///   - file: The calling file, where an issue points. Leave the default.
    ///   - line: The calling line, where an issue points. Leave the default.
    ///   - onFinish: Gets the flow's result, once.
    @discardableResult
    public func push<Child: FlowCoordinating>(
        _ child: Child,
        trigger: String? = nil,
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line,
        onFinish: @escaping @MainActor (FlowResult<Child.Output>) -> Void
    ) -> NavigationOutcome {
        push(trigger: trigger, else: fallback, file: file, line: line, onFinish: onFinish) {
            child
        }
    }

    /// Pushes the flow of the coordinator `makeChild` returns on this stack, building it only when
    /// the push happens. Otherwise this behaves as ``push(_:trigger:else:file:line:onFinish:)``,
    /// and `makeChild` runs as in ``present(style:trigger:else:file:line:onFinish:_:)``.
    ///
    /// - Parameters:
    ///   - trigger: What in the screen started it, written in the journey box. Default: `nil`.
    ///   - fallback: What to do if the push fails. Default: the flow's policy.
    ///   - file: The calling file, where an issue points. Leave the default.
    ///   - line: The calling line, where an issue points. Leave the default.
    ///   - onFinish: Gets the flow's result, once.
    ///   - makeChild: Builds the coordinator of the pushed flow.
    @discardableResult
    public func push<Child: FlowCoordinating>(
        trigger: String? = nil,
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line,
        onFinish: @escaping @MainActor (FlowResult<Child.Output>) -> Void,
        _ makeChild: @escaping @MainActor () -> Child
    ) -> NavigationOutcome {
        perform(file: file, line: line, fallback: fallback, trigger: trigger) { router, store in
            router.pushChildStep(file: file, line: line, in: store, onFinish: onFinish, makeChild)
        }
    }

    /// Pushes the marker of the child flow `makeChild` returns, whose router joins this router's
    /// tree as the flow on top of this stack. A child flow already on top ends first. A push of
    /// the flow still being pushed, such as the second tap of a double tap, builds nothing when the
    /// duplicate push rule skips it.
    func pushChildStep<Child: FlowCoordinating>(
        file: StaticString,
        line: UInt,
        in store: TransactionStore,
        onFinish: @escaping @MainActor (FlowResult<Child.Output>) -> Void,
        _ makeChild: () -> Child
    ) -> StepResult {
        store.enlist(self)
        if let skipped = pushOfFlowInFlight(of: Child.self) {
            store.noteSkippedPush(skipped)
            return .unchanged
        }
        let table = RouterTable.shared
        let child = table.build(makeChild, joining: tree, file: file, line: line)
        let router = table.checkedRouter(of: child, file: file, line: line)
        if let refusal = refusal(toStart: router, of: child, ownsRouter: table.ownsRouter(of: child)) {
            return .failed(refusal)
        }
        let flow = ChildFlow(coordinator: child, onFinish: onFinish)
        let name = FlowNaming.childFlowName(of: router, for: child)
        router.join(startedBy: self, named: name, flow: flow, pushed: true)
        guard let marker = router.marker else {
            return undoingJoin(of: router, result: .unchanged)
        }
        let below = current.state.path.filter { route in
            route != current.pushed?.marker
        }
        switch StackReducer.reduce(current.state.withPath(below), .push(marker), rootRoute: rootRoute) {
        case .changed(let next, let changes):
            updateWorkingCopy { snapshot in
                snapshot.pushing(router, state: next)
            }
            store.record(changes, in: flowID)
            return .changed
        case .unchanged:
            return undoingJoin(of: router, result: .unchanged)
        case .rejected(let rejection):
            return undoingJoin(of: router, result: .failed(draft(rejection)))
        }
    }

    /// The marker of the child flow on top when it is a `type` flow still being pushed and the
    /// duplicate push rule skips such pushes, or `nil` when the push goes ahead.
    private func pushOfFlowInFlight(of type: Any.Type) -> AnyRoute? {
        guard duplicatePushRule == .skipWhileInFlight, let pushed = current.pushed else {
            return nil
        }
        guard let marker = pushed.marker, pushInFlight == marker else {
            return nil
        }
        return pushed.childFlow?.coordinatorType == ObjectIdentifier(type) ? marker : nil
    }

    /// Pops this stack back to the screen below the marker of `child`, the child flow on top,
    /// which ends it.
    func popPushedChildStep(_ child: StackRouter, in store: TransactionStore) -> StepResult {
        store.enlist(self)
        let path = current.state.path
        guard let marker = child.marker, let index = path.lastIndex(of: marker) else {
            return .unchanged
        }
        return stackStep(.pop(count: path.count - index), in: store)
    }
}
