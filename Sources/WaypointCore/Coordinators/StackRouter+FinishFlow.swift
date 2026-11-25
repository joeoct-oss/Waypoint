//
//  StackRouter+FinishFlow.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// Finishing a child flow from a screen inside it, for `@FinishFlow` in `Waypoint`.
extension StackRouter {
    /// Ends the nearest child flow of `coordinator`'s type at or above this router with `output`,
    /// as the coordinator's `finish(with:)` does: the parent gets `.finished(output)`, and the
    /// flow is dismissed, or popped when it was pushed. `package`: views finish with
    /// `@FinishFlow` in `Waypoint`.
    ///
    /// When no such flow is at or above this router, nothing changes: it fails with
    /// `noRouterInScope`, which names the coordinator, `wrapper` and the declaration's site, and
    /// is reported. A flow that already ended ignores the call.
    ///
    /// - Parameters:
    ///   - coordinator: The flow's coordinator type.
    ///   - output: The value the flow ends with.
    ///   - wrapper: The call site of the declaration that asked, such as
    ///     `@FinishFlow(ReviewCoordinator.self) in ReviewView.swift:12`, named in the issue.
    ///   - file: The calling file, where an issue points.
    ///   - line: The calling line, where an issue points.
    @discardableResult
    package func finishFlow<Output: Sendable>(
        of coordinator: Any.Type,
        with output: Output,
        wrapper: String,
        file: StaticString,
        line: UInt
    ) -> NavigationOutcome {
        guard isActive else {
            return dismissFlow(file: file, line: line)
        }
        guard let flow = flowRouter(of: coordinator) else {
            return reportNoFlowInScope(of: coordinator, wrapper: wrapper, file: file, line: line)
        }
        if let record = flow.childFlow as? ChildFlow<Output> {
            record.keep(output)
        }
        return flow.dismissFlow(file: file, line: line)
    }

    /// Whether a child flow of `coordinator`'s type is at or above this router and still running.
    package func isInFlow(of coordinator: Any.Type) -> Bool {
        flowRouter(of: coordinator)?.isActive ?? false
    }

    /// The nearest router at or above this one that runs a child flow of `coordinator`'s type.
    private func flowRouter(of coordinator: Any.Type) -> StackRouter? {
        let type = ObjectIdentifier(coordinator)
        let routers = sequence(first: self as any TreeNode, next: \.parentNode).compactMap { node in
            node as? StackRouter
        }
        return routers.first { router in
            router.childFlow?.coordinatorType == type
        }
    }

    /// Reports `noRouterInScope` for a finish with no flow of `coordinator`'s type above this
    /// router, and fails.
    private func reportNoFlowInScope(
        of coordinator: Any.Type,
        wrapper: String,
        file: StaticString,
        line: UInt
    ) -> NavigationOutcome {
        let name = ViewTypeName.of(coordinator)
        let message = "\(wrapper) found no \(name) flow above its view, so nothing finished. Use it "
            + "in a screen of \(name)'s flow, or call finish(with:) on the coordinator."
        let issue = NavigationIssue(kind: .noRouterInScope, flow: flowID, message: message, file: file, line: line)
        tree.report(issue, level: .error)
        return .failed(NavigationFailure(issue: issue))
    }
}
