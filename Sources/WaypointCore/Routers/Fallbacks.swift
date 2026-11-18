//
//  Fallbacks.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// What a fallback needs to know about the call it stands in for.
struct FallbackContext {
    /// The call's own fallback, if it passed one.
    let explicit: NavigationFallback?

    /// The route of a `popTo` route call, for the `.push` fallback.
    let route: AnyRoute?

    /// The route and style of a `present` call, for the `.replacePresentation` fallback.
    let presentation: PresentationRequest?

    /// The file of the call.
    let file: StaticString

    /// The line of the call.
    let line: UInt

    /// A context for one call. `route` and `presentation` are only given by the calls that use
    /// them.
    init(
        explicit: NavigationFallback?,
        route: AnyRoute? = nil,
        presentation: PresentationRequest? = nil,
        file: StaticString,
        line: UInt
    ) {
        self.explicit = explicit
        self.route = route
        self.presentation = presentation
        self.file = file
        self.line = line
    }
}

/// What a `present` call asked for, kept so the `.replacePresentation` fallback can present it.
struct PresentationRequest {
    /// The route to present as the new flow's root screen.
    let route: AnyRoute

    /// How to present it.
    let style: PresentationStyle
}

extension TransactionStore {
    /// Turns one step's result into the call's result, running a fallback when the step failed.
    func resolve(_ result: StepResult, on router: any PresentingRouter, _ context: FallbackContext) -> CallResult {
        switch result {
        case .changed:
            return .changed
        case .unchanged:
            return .unchanged
        case .failed(let draft):
            return recover(from: draft.issue(file: context.file, line: context.line), on: router, context)
        }
    }

    /// Runs the chosen fallback once, in this transaction. A fallback never triggers another.
    private func recover(
        from issue: NavigationIssue,
        on router: any PresentingRouter,
        _ context: FallbackContext
    ) -> CallResult {
        let fallback = context.explicit ?? router.policyFallback(for: issue.kind) ?? .builtIn(for: issue.kind)
        guard origin != .fallback, fallback != .none else {
            return failed(issue)
        }
        guard let fallbackIssue = runFallback(fallback, on: router, after: issue, context) else {
            keep(issue, level: .error)
            return .recovered(issue, fallback)
        }
        return failed(issue, fallback: fallback, fallbackIssue: fallbackIssue)
    }

    /// Runs a fallback with its changes marked as coming from a fallback. Returns its issue if
    /// it failed.
    private func runFallback(
        _ fallback: NavigationFallback,
        on router: any PresentingRouter,
        after issue: NavigationIssue,
        _ context: FallbackContext
    ) -> NavigationIssue? {
        asFallback {
            runFallbackSteps(fallback, on: router, after: issue, context)
        }
    }

    /// The steps of one fallback. Returns its issue if it failed.
    private func runFallbackSteps(
        _ fallback: NavigationFallback,
        on router: any PresentingRouter,
        after issue: NavigationIssue,
        _ context: FallbackContext
    ) -> NavigationIssue? {
        switch fallback {
        case .none:
            return nil
        case .popToRoot:
            return issueOf(popToRootStep(on: router), context)
        case .push:
            return issueOf(pushStep(context.route, on: router), context)
        case .dismissAll:
            return issueOf(router.dismissAllStep(in: self), context)
        case .resetToRoot:
            return issueOf(resetStep(from: router), context)
        case .replacePresentation:
            return issueOf(replacePresentationStep(context.presentation, on: router), context)
        case .custom(_, let change):
            return runCustom(change, on: router, after: issue)
        }
    }

    /// Pops the router's stack, or a tab container's selected stack, to its root.
    private func popToRootStep(on router: any PresentingRouter) -> StepResult {
        guard let stack = router.visibleStack else {
            return .unchanged
        }
        return stack.stackStep(.popToRoot, in: self)
    }

    /// Pushes the route a `popTo` call asked for.
    private func pushStep(_ route: AnyRoute?, on router: any PresentingRouter) -> StepResult {
        guard let route, let stack = router as? StackRouter else {
            let message = "The .push fallback only applies to popTo with a route value on a stack."
            return .failed(IssueDraft(kind: .fallbackFailed, flow: router.flowID, message: message))
        }
        let routes = [route]
        return stack.pushStep(routes, in: self)
    }

    /// Dismisses everything from the root, then pops the root's visible stack.
    private func resetStep(from router: any PresentingRouter) -> StepResult {
        guard let root = router.rootNode as? any PresentingRouter else {
            return .unchanged
        }
        let dismissed = root.dismissAllStep(in: self)
        if case .failed = dismissed {
            return dismissed
        }
        let popped = popToRootStep(on: root)
        if case .failed = popped {
            return popped
        }
        let changed = dismissed.isChanged || popped.isChanged
        return changed ? .changed : .unchanged
    }

    /// Dismisses the router's presented flow with everything above it, then presents the call's
    /// route.
    private func replacePresentationStep(
        _ request: PresentationRequest?,
        on router: any PresentingRouter
    ) -> StepResult {
        guard let request else {
            let message = "The .replacePresentation fallback only applies to present."
            return .failed(IssueDraft(kind: .fallbackFailed, flow: router.flowID, message: message))
        }
        let dismissed = router.dismissStep(in: self)
        if case .failed = dismissed {
            return dismissed
        }
        return router.presentStep(request.route, style: request.style, in: self)
    }

    /// Runs a custom fallback through a transaction value. Its first failed step is its issue.
    private func runCustom(
        _ change: @MainActor @Sendable (NavigationTransaction, NavigationIssue) -> Void,
        on router: any PresentingRouter,
        after issue: NavigationIssue
    ) -> NavigationIssue? {
        isolatingFailure {
            change(NavigationTransaction(store: self, target: router), issue)
        }
    }

    /// A failed step's issue at the call site, or `nil` when the step worked.
    private func issueOf(_ result: StepResult, _ context: FallbackContext) -> NavigationIssue? {
        guard case .failed(let draft) = result else {
            return nil
        }
        return draft.issue(file: context.file, line: context.line)
    }

    /// A failure to report when the transaction ends.
    private func failed(
        _ issue: NavigationIssue,
        fallback: NavigationFallback? = nil,
        fallbackIssue: NavigationIssue? = nil
    ) -> CallResult {
        keep(issue, level: .fault)
        return .failed(NavigationFailure(issue: issue, fallback: fallback, fallbackIssue: fallbackIssue))
    }
}

extension StepResult {
    /// Whether the step changed something.
    var isChanged: Bool {
        guard case .changed = self else {
            return false
        }
        return true
    }
}
