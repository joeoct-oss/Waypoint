//
//  PresentingRouter.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// A router that can present one child flow: a stack or a tab container.
///
/// Conformances:
/// - `TreeNode`, so presenting changes the tree.
@MainActor
protocol PresentingRouter: TreeNode {
    /// The working copy's presentation. Valid only while enlisted in a transaction.
    var workingPresentation: Presentation? { get set }

    /// The working copy's presented router. Valid only while enlisted in a transaction.
    var workingPresented: StackRouter? { get set }

    /// The routers inside this flow that are not presented, such as each tab's stack.
    var workingInFlowChildren: [any PresentingRouter] { get }
}

extension PresentingRouter {
    /// Presents `route` as the root screen of a new child flow.
    func presentStep(_ route: AnyRoute, style: PresentationStyle, in store: TransactionStore) -> StepResult {
        guard tree.hasDestination(for: route) else {
            return .failed(unregisteredDraft(route))
        }
        store.enlist(self)
        let flow = tree.claimFlowName(FlowNaming.baseName(for: route))
        let presentation = Presentation(style: style, flow: flow, route: route)
        switch PresentationReducer.reduce(PresentationOnly(presentation: workingPresentation), .present(presentation)) {
        case .changed(_, let changes):
            return attach(StackRouter(presentedBy: self, flow: flow, route: route), presentation, changes, in: store)
        case .unchanged:
            return release(flow, result: .unchanged)
        case .rejected(let rejection):
            return release(flow, result: .failed(draft(rejection)))
        }
    }

    /// Dismisses the presented flow and everything it presents.
    func dismissStep(in store: TransactionStore) -> StepResult {
        store.enlist(self)
        switch PresentationReducer.reduce(PresentationOnly(presentation: workingPresentation), .dismiss) {
        case .changed(_, let changes):
            return detachPresented(changes: changes, in: store)
        case .unchanged:
            return .unchanged
        case .rejected(let rejection):
            return .failed(draft(rejection))
        }
    }

    /// Dismisses everything presented over this flow, including over its tabs.
    func dismissAllStep(in store: TransactionStore) -> StepResult {
        store.enlist(self)
        var changed = isChanged(dismissStep(in: store))
        for child in workingInFlowChildren {
            changed = isChanged(child.dismissAllStep(in: store)) || changed
        }
        return changed ? .changed : .unchanged
    }

    /// Asks the router that presented this flow to dismiss it.
    func dismissFlowStep(in store: TransactionStore) -> StepResult {
        guard let presenter = presenter() as? any PresentingRouter else {
            return .failed(notPresentedDraft())
        }
        return presenter.dismissStep(in: store)
    }

    /// An issue for a rejection on this flow.
    func draft(_ rejection: Rejection) -> IssueDraft {
        IssueDraft(kind: rejection.kind, flow: flowID, message: rejection.message(path: currentPath))
    }

    /// An issue for a route type with no destination.
    func unregisteredDraft(_ route: AnyRoute) -> IssueDraft {
        let name = route.routeKey.typeName
        let message = "No destination is registered for \(name). "
            + "Register one with .destination(\(name).self) or in the coordinator's destinations."
        return IssueDraft(kind: .unregisteredRoute, flow: flowID, message: message)
    }

    /// Stores the new child and records the change.
    private func attach(
        _ child: StackRouter,
        _ presentation: Presentation,
        _ changes: [NavigationChange],
        in store: TransactionStore
    ) -> StepResult {
        workingPresentation = presentation
        workingPresented = child
        store.record(changes, in: flowID)
        return .changed
    }

    /// Frees the name claimed for a child that was not created.
    private func release(_ flow: FlowID, result: StepResult) -> StepResult {
        tree.releaseFlowName(flow)
        return result
    }

    /// Clears the presented flow and records the change.
    private func detachPresented(changes: [NavigationChange], in store: TransactionStore) -> StepResult {
        workingPresentation = nil
        workingPresented = nil
        store.record(changes, in: flowID)
        return .changed
    }

    /// An issue for `dismissFlow` on a flow that nobody presented.
    private func notPresentedDraft() -> IssueDraft {
        let message = "\(flowID) is not presented, so dismissFlow() has nothing to dismiss. "
            + "Only a presented flow can dismiss itself."
        return IssueDraft(kind: .notPresented, flow: flowID, message: message)
    }

    /// Whether a step changed something. A failed dismiss can't happen, so it counts as unchanged.
    private func isChanged(_ result: StepResult) -> Bool {
        guard case .changed = result else {
            return false
        }
        return true
    }
}

/// Just a presentation, so the presentation reducer can run on either router's working copy.
///
/// Conformances:
/// - `PresentingState`, so the presentation reducer accepts it.
struct PresentationOnly: PresentingState {
    /// The presented flow, if any.
    var presentation: Presentation?
}

/// The base flow name for a presented route: `SettingsRoute` becomes `settings`.
enum FlowNaming {
    /// The type name without nesting, generics or a `Route` suffix, starting lowercase.
    static func baseName(for route: AnyRoute) -> String {
        let typeName = route.routeKey.typeName
        let withoutGenerics = typeName.split(separator: "<").first.map(String.init) ?? typeName
        let lastPart = withoutGenerics.split(separator: ".").last.map(String.init) ?? withoutGenerics
        let trimmed = lastPart.hasSuffix("Route") && lastPart != "Route" ? String(lastPart.dropLast(5)) : lastPart
        guard let first = trimmed.first else {
            return "flow"
        }
        return first.lowercased() + trimmed.dropFirst()
    }
}
