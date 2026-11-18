//
//  StackRouter+Paths.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

extension StackRouter {
    /// Pushes several routes as one change, with one animation.
    @discardableResult
    public func push(
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line,
        @RoutePathBuilder _ routes: () -> [AnyRoute]
    ) -> NavigationOutcome {
        let built = routes()
        return perform(file: file, line: line, fallback: fallback) { router, store in
            router.pushStep(built, in: store)
        }
    }

    /// Replaces the whole path as one change.
    @discardableResult
    public func setPath(
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line,
        @RoutePathBuilder _ routes: () -> [AnyRoute]
    ) -> NavigationOutcome {
        let built = routes()
        return perform(file: file, line: line, fallback: fallback) { router, store in
            router.setPathStep(built, in: store)
        }
    }

    /// Pops to the last route of type `R` that matches `predicate`.
    ///
    /// If none does but the stack's root screen does, this pops to root. Otherwise it fails with
    /// `routeNotInPath`.
    @discardableResult
    public func popTo<R: Route>(
        _ type: R.Type,
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line,
        where predicate: @escaping (R) -> Bool = { _ in true }
    ) -> NavigationOutcome {
        perform(file: file, line: line, fallback: fallback) { router, store in
            router.popToStep(type, where: predicate, in: store)
        }
    }

    /// Applies several changes as one: the state changes once, the renderer draws once, and
    /// observers get one batch.
    ///
    /// ```swift
    /// router.transaction {
    ///     $0.popToRoot()
    ///     $0.push(ProductRoute(id: 42))
    /// }
    /// ```
    ///
    /// If any step fails, the whole transaction is rolled back and the outcome is that step's
    /// failure, with the step's file and line.
    @discardableResult
    public func transaction(
        file: StaticString = #fileID,
        line: UInt = #line,
        _ body: @escaping (NavigationTransaction) -> Void
    ) -> NavigationOutcome {
        tree.perform(on: self, file: file, line: line) { [unowned self] store in
            NavigationTransaction.run(body, on: self, in: store)
        }
    }

    /// Whether the path contains this route.
    public func contains<R: Route>(_ route: R) -> Bool {
        state.path.contains(AnyRoute(route))
    }

    /// The route of type `R` nearest the top of the path, or `nil`.
    public func last<R: Route>(_ type: R.Type) -> R? {
        state.path.reversed().lazy.compactMap { $0.as(R.self) }.first
    }

    /// Replaces the path in the working copy, after checking each route has a destination.
    func setPathStep(_ routes: [AnyRoute], in store: TransactionStore) -> StepResult {
        if let missing = routes.first(where: { !tree.hasDestination(for: $0) }) {
            return .failed(unregisteredDraft(missing))
        }
        return stackStep(.setPath(routes), in: store)
    }

    /// Pops to the last matching route of a type, or to the root when only the root matches.
    func popToStep<R: Route>(_ type: R.Type, where predicate: (R) -> Bool, in store: TransactionStore) -> StepResult {
        store.enlist(self)
        let path = current.state.path
        if let match = path.last(where: { $0.as(R.self).map(predicate) ?? false }) {
            return stackStep(.popTo(match), in: store)
        }
        guard let rootRoute, rootRoute.as(R.self).map(predicate) ?? false else {
            return .failed(draft(.typeNotInPath(R.routeKey)))
        }
        return stackStep(.popToRoot, in: store)
    }
}

extension TabRouter {
    /// Applies several changes as one, across the container, its tabs and presented flows.
    ///
    /// ```swift
    /// tabs.transaction {
    ///     $0.dismissAll()
    ///     $0.select(MainTab.shop)
    ///     $0.router(for: MainTab.shop).setPath {
    ///         ProductListRoute(category: "all")
    ///         ProductRoute(id: 42)
    ///     }
    /// }
    /// ```
    ///
    /// If any step fails, the whole transaction is rolled back.
    @discardableResult
    public func transaction(
        file: StaticString = #fileID,
        line: UInt = #line,
        _ body: @escaping (NavigationTransaction) -> Void
    ) -> NavigationOutcome {
        tree.perform(on: self, file: file, line: line) { [unowned self] store in
            NavigationTransaction.run(body, on: self, in: store)
        }
    }
}
