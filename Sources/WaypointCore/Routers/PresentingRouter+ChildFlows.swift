//
//  PresentingRouter+ChildFlows.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

extension PresentingRouter {
    /// Presents the flow of the child coordinator `makeChild` returns, whose router joins this
    /// router's tree. `makeChild` runs only once the present will happen, so a refused present
    /// builds nothing. The parent gets the flow's result in `onFinish` exactly once, after the
    /// start commits.
    func presentChildStep<Child: FlowCoordinating>(
        style: PresentationStyle,
        file: StaticString,
        line: UInt,
        in store: TransactionStore,
        onFinish: @escaping @MainActor (FlowResult<Child.Output>) -> Void,
        _ makeChild: () -> Child
    ) -> StepResult {
        store.enlist(self)
        let probe = Presentation(style: style, flow: flowID)
        let state = PresentationOnly(presentation: workingPresentation)
        if case .rejected(let rejection) = PresentationReducer.reduce(state, .present(probe)) {
            return .failed(draft(rejection))
        }
        let table = RouterTable.shared
        let child = table.build(makeChild, joining: tree, file: file, line: line)
        let router = table.checkedRouter(of: child, file: file, line: line)
        if let refusal = refusal(toStart: router, of: child, ownsRouter: table.ownsRouter(of: child)) {
            return .failed(refusal)
        }
        let flow = ChildFlow(coordinator: child, onFinish: onFinish)
        router.join(presentedBy: self, named: FlowNaming.childFlowName(of: router, for: child), flow: flow)
        let presentation = Presentation(style: style, flow: router.flowID)
        switch PresentationReducer.reduce(state, .present(presentation)) {
        case .changed(_, let changes):
            updateWorkingPresentation(presentation, presented: router)
            store.record(changes, in: flowID)
            return .changed
        case .unchanged:
            return undoingJoin(of: router, result: .unchanged)
        case .rejected(let rejection):
            return undoingJoin(of: router, result: .failed(draft(rejection)))
        }
    }

    /// Frees the name of a presented router whose present was rolled back, or puts a child's
    /// router that joined for it back where it was.
    func releaseUncommitted(_ created: StackRouter) {
        guard !created.undoJoin() else {
            return
        }
        tree.releaseFlowName(created.flowID)
    }

    /// Why `router`, the router of `child`, can't start as a child flow of this router, or `nil`
    /// when it can: it is this router or one above it, or it already has a parent, belongs to
    /// another coordinator or has ended.
    private func refusal(toStart router: StackRouter, of child: AnyObject, ownsRouter: Bool) -> IssueDraft? {
        let name = ViewTypeName.of(type(of: child))
        let isAncestor = sequence(first: self as any TreeNode, next: \.parentNode).contains { node in
            node === router
        }
        if isAncestor {
            let message = "\(name)'s router is \(flowID)'s own router or one above it, so it can't start "
                + "as \(flowID)'s child flow: a router can't be its own child. Give \(name) a router "
                + "of its own: don't return a parent's router from makeRouter()."
            return IssueDraft(kind: .childRouterIsAncestor, flow: flowID, message: message)
        }
        guard ownsRouter, router.canJoinAnotherTree else {
            let message = "\(name)'s router is already in another tree, such as a tab's or another "
                + "flow's, belongs to another coordinator, or ended with an earlier flow, so \(name) "
                + "can't start as \(flowID)'s child flow. Start a new \(name), whose router Waypoint "
                + "makes, or make a new router in \(name).makeRouter()."
            return IssueDraft(kind: .routerInAnotherTree, flow: flowID, message: message)
        }
        return nil
    }

    /// Puts `router` back where it was before it joined, and returns `result`.
    private func undoingJoin(of router: StackRouter, result: StepResult) -> StepResult {
        _ = router.undoJoin()
        return result
    }
}

extension FlowNaming {
    /// The name of a child coordinator's flow: its router's own name, unless that is the default
    /// `main`, then the coordinator's type name without `Coordinator`, starting lowercase:
    /// `checkout` for `CheckoutCoordinator`.
    @MainActor
    static func childFlowName(of router: StackRouter, for child: AnyObject) -> String {
        guard router.flowID.name == defaultFlowName else {
            return router.flowID.name
        }
        return baseName(forCoordinator: type(of: child))
    }

    /// The coordinator type's name without `Coordinator`, starting lowercase.
    @MainActor
    static func baseName(forCoordinator type: Any.Type) -> String {
        let name = RouterTable.typeRootName(of: type)
        guard let first = name.first else {
            return "flow"
        }
        return first.lowercased() + name.dropFirst()
    }

    /// The flow name a router gets when none is given.
    static let defaultFlowName = "main"
}
