// Throwaway spike C (flow routes) code. Rough on purpose; never merged.
//
// Question: can a coordinator be rebuilt from a route (link, restore), and does a child flow's
// result reach a handler that the parent registered with `onResult(FlowRoute.self)` after a
// restore, when nobody is awaiting any more?
//
// Shape under test:
// - A `FlowRoute` is a plain route that stands for a coordinator flow, with a `Result` type.
// - The app registers one factory per flow route, like a destination: `.flow(CheckoutRoute.self) { ... }`.
// - Coordinators are never created by hand. `FlowHost.sync()` walks the router tree and creates
//   the coordinator for every flow route it finds (a presented flow's root route, or a pushed flow
//   route inside a path), and ends the coordinators whose route left the tree. Presenting, a link
//   and a restore all go through that one walk.
// - A parent coordinator registers result handlers by flow route type in its `init`, so a
//   rebuilt parent has them again. `await present(...)` is sugar over the same delivery.

import Foundation
import WaypointCore

/// A route that stands for a coordinator flow.
public protocol FlowRoute: Route {
    /// What the flow hands back when it finishes.
    associatedtype Result: Sendable
}

/// How a child flow ended.
public enum FlowResult<Value: Sendable>: Sendable {
    case finished(Value)
    case cancelled
}

/// Where a coordinator sits: the presented root of a stack, or a pushed flow route at an index.
struct FlowKey: Hashable {
    let router: ObjectIdentifier
    /// `nil` for the presented root route of the router; otherwise the index in the path.
    let index: Int?
}

/// What the host records about one live coordinator.
@MainActor
final class FlowRecord {
    let key: FlowKey
    let route: AnyRoute
    let coordinator: Coordinator
    weak var router: StackRouter?

    init(key: FlowKey, route: AnyRoute, coordinator: Coordinator, router: StackRouter) {
        self.key = key
        self.route = route
        self.coordinator = coordinator
        self.router = router
    }
}

/// The base of every coordinator in the spike.
@MainActor
open class Coordinator {
    /// The stack this flow runs on. A pushed flow shares its parent's stack.
    public let router: StackRouter
    /// The flow route this coordinator was built from, or `nil` for the app coordinator.
    public let route: AnyRoute?
    /// Set by the host when it creates or adopts the coordinator.
    public internal(set) weak var host: FlowHost?
    /// Handlers by flow route key.
    var handlers: [RouteKey: (Any) -> Void] = [:]
    /// Awaiting callers by flow route key (cleared by a restore, since they live in memory).
    var waiters: [RouteKey: (Any) -> Void] = [:]
    public internal(set) var isFinished = false

    public init(router: StackRouter, route: AnyRoute?) {
        self.router = router
        self.route = route
    }

    /// Registers what to do when a child flow of type `R` ends. Call it in `init`, so a rebuilt
    /// coordinator has it again after a restore.
    public func onResult<R: FlowRoute>(_ type: R.Type, _ handler: @escaping @MainActor (FlowResult<R.Result>) -> Void) {
        handlers[R.routeKey] = { value in
            // The spike passes FlowResult<R.Result> as Any.
            handler(value as! FlowResult<R.Result>)
        }
    }

    /// Presents a child flow by its route. The host builds the coordinator.
    @discardableResult
    public func present<R: FlowRoute>(_ route: R, style: PresentationStyle = .sheet) -> NavigationOutcome {
        let outcome = router.present(route, style: style)
        host?.sync()
        return outcome
    }

    /// Pushes a child flow on this stack. The host builds the coordinator.
    @discardableResult
    public func push<R: FlowRoute>(flow route: R) -> NavigationOutcome {
        let outcome = router.push(route)
        host?.sync()
        return outcome
    }

    /// Presents a child flow and waits for its result. Lives in memory only.
    public func presentAndWait<R: FlowRoute>(_ route: R) async -> FlowResult<R.Result> {
        await withCheckedContinuation { continuation in
            waiters[R.routeKey] = { value in
                continuation.resume(returning: value as! FlowResult<R.Result>)
            }
            if case .failed = present(route) {
                waiters[R.routeKey] = nil
                continuation.resume(returning: .cancelled)
            }
        }
    }

    /// Ends this flow with a result: the parent's handler gets it, then the flow leaves the screen.
    public func finish<R: FlowRoute>(_ type: R.Type, with value: R.Result) {
        host?.finish(self, routeKey: R.routeKey, result: FlowResult<R.Result>.finished(value))
    }

    /// The spike calls this when the host drops the coordinator.
    open func didEnd() { }
}

/// One factory per flow route type.
@MainActor
struct FlowFactory {
    let make: (AnyRoute, StackRouter) -> Coordinator
    let cancelled: () -> Any
    /// Presents the erased route inside a transaction (the spike can't reach `AnyRoute.base`).
    let present: (AnyRoute, PresentationStyle, NavigationTransaction) -> Void
}

/// Owns the coordinators of one window: builds them from the router tree and delivers results.
@MainActor
public final class FlowHost {
    public private(set) var rootRouter: StackRouter
    public private(set) var appCoordinator: Coordinator
    private var factories: [RouteKey: FlowFactory] = [:]
    private var screens: [RouteKey: (AnyRoute, PresentationStyle, NavigationTransaction) -> Void] = [:]
    private var records: [FlowKey: FlowRecord] = [:]
    private let makeApp: (StackRouter) -> Coordinator
    /// Every result delivery, as text, for tests.
    public private(set) var log: [String] = []
    public private(set) var registry = RouteRegistry()

    public init(root: StackRouter, makeApp: @escaping (StackRouter) -> Coordinator) {
        self.rootRouter = root
        self.makeApp = makeApp
        self.appCoordinator = makeApp(root)
        appCoordinator.host = self
    }

    /// `.flow(CheckoutRoute.self) { route, router in CheckoutCoordinator(...) }`
    public func flow<R: FlowRoute>(_ type: R.Type, make: @escaping @MainActor (R, StackRouter) -> Coordinator) {
        registry = registry.registering(type)
        factories[R.routeKey] = FlowFactory(
            make: { route, router in make(route.as(R.self)!, router) },
            cancelled: { FlowResult<R.Result>.cancelled },
            present: { route, style, transaction in transaction.present(route.as(R.self)!, style: style) }
        )
    }

    /// A plain screen route, so restore can present and decode it.
    public func screen<R: Route>(_ type: R.Type) {
        registry = registry.registering(type)
        screens[R.routeKey] = { route, style, transaction in transaction.present(route.as(R.self)!, style: style) }
    }

    /// The live coordinator for a flow route type, for tests.
    public func coordinator<R: FlowRoute>(for type: R.Type) -> Coordinator? {
        records.values.first { $0.route.is(type) }?.coordinator
    }

    public var liveFlowCount: Int {
        records.count
    }

    // MARK: Walk

    /// Builds missing coordinators top-down and ends the ones whose route left the tree.
    public func sync() {
        var seen: Set<FlowKey> = []
        walk(rootRouter, seen: &seen)
        for (key, record) in records where !seen.contains(key) {
            records[key] = nil
            if !record.coordinator.isFinished {
                // The user (or a dismissAll, or a link) closed it without a result.
                record.coordinator.isFinished = true
                deliver(from: record, routeKey: record.route.routeKey, result: factories[record.route.routeKey]!.cancelled())
            }
            record.coordinator.didEnd()
        }
    }

    private func walk(_ router: StackRouter, seen: inout Set<FlowKey>) {
        if let root = router.rootRoute, router !== rootRouter, factories[root.routeKey] != nil {
            adopt(FlowKey(router: ObjectIdentifier(router), index: nil), root, router, &seen)
        }
        for (index, route) in router.state.path.enumerated() where factories[route.routeKey] != nil {
            adopt(FlowKey(router: ObjectIdentifier(router), index: index), route, router, &seen)
        }
        if let presented = router.presented {
            walk(presented, seen: &seen)
        }
    }

    private func adopt(_ key: FlowKey, _ route: AnyRoute, _ router: StackRouter, _ seen: inout Set<FlowKey>) {
        seen.insert(key)
        if let existing = records[key], existing.route == route {
            return
        }
        let coordinator = factories[route.routeKey]!.make(route, router)
        coordinator.host = self
        records[key] = FlowRecord(key: key, route: route, coordinator: coordinator, router: router)
        log.append("built \(route.routeKey.rawValue)")
    }

    // MARK: Results

    func finish(_ child: Coordinator, routeKey: RouteKey, result: Any) {
        guard let record = records.values.first(where: { $0.coordinator === child }), !child.isFinished else {
            log.append("finish ignored: flow not live")
            return
        }
        child.isFinished = true
        deliver(from: record, routeKey: routeKey, result: result)
        // Then the flow leaves the screen: dismiss a presented flow, or pop a pushed one.
        if let index = record.key.index, let router = record.router {
            router.pop(count: router.state.path.count - index)
        } else {
            record.router?.dismissFlow()
        }
        sync()
    }

    private func deliver(from record: FlowRecord, routeKey: RouteKey, result: Any) {
        guard let parent = parent(of: record) else {
            log.append("unhandled \(routeKey.rawValue): no parent")
            return
        }
        if let waiter = parent.waiters.removeValue(forKey: routeKey) {
            waiter(result)
            log.append("awaited \(routeKey.rawValue) \(Self.describe(result))")
        } else if let handler = parent.handlers[routeKey] {
            handler(result)
            log.append("handled \(routeKey.rawValue) \(Self.describe(result))")
        } else {
            log.append("unhandled \(routeKey.rawValue) \(Self.describe(result))")
        }
    }

    private static func describe(_ result: Any) -> String {
        String(describing: result).contains("cancelled") ? "cancelled" : "finished"
    }

    /// The nearest coordinator above `record`: a flow pushed earlier on the same stack, the
    /// stack's own flow, then the same up the presenting stacks, then the app coordinator.
    private func parent(of record: FlowRecord) -> Coordinator? {
        guard let router = record.router else {
            return nil
        }
        let startIndex = record.key.index ?? -1
        if let found = owner(of: router, below: startIndex, includeRoot: record.key.index != nil) {
            return found
        }
        var current: (any NavigationRouter)? = router.parent
        while let stack = current as? StackRouter {
            if let found = owner(of: stack, below: stack.state.path.count, includeRoot: true) {
                return found
            }
            current = stack.parent
        }
        return appCoordinator
    }

    /// The coordinator owning the part of `router`'s stack below `index`.
    private func owner(of router: StackRouter, below index: Int, includeRoot: Bool) -> Coordinator? {
        let id = ObjectIdentifier(router)
        if index > 0 {
            for candidate in stride(from: index - 1, through: 0, by: -1) {
                if let record = records[FlowKey(router: id, index: candidate)] {
                    return record.coordinator
                }
            }
        }
        if includeRoot, let record = records[FlowKey(router: id, index: nil)] {
            return record.coordinator
        }
        return nil
    }

    // MARK: Saving and restoring

    /// The spike's own snapshot (core snapshots, #55, aren't built yet): routes only.
    public struct Snapshot: Codable, Sendable {
        public let path: [AnyRoute]
        public let presentedRoute: AnyRoute?
        public let presentedStyle: PresentationStyle?
        public let presented: [Snapshot]

        public init(path: [AnyRoute], presentedRoute: AnyRoute? = nil, presentedStyle: PresentationStyle? = nil, presented: [Snapshot] = []) {
            self.path = path
            self.presentedRoute = presentedRoute
            self.presentedStyle = presentedStyle
            self.presented = presented
        }
    }

    public func snapshot() -> Snapshot {
        Self.snapshot(of: rootRouter)
    }

    private static func snapshot(of router: StackRouter) -> Snapshot {
        Snapshot(
            path: router.state.path,
            presentedRoute: router.presented?.rootRoute,
            presentedStyle: router.state.presentation?.style,
            presented: router.presented.map { [snapshot(of: $0)] } ?? []
        )
    }

    /// Throws away every router and coordinator, then rebuilds from `snapshot` in one transaction.
    /// In-memory awaiters are gone, as they would be after the app was killed.
    public func restore(_ snapshot: Snapshot, root: StackRouter) {
        records = [:]
        rootRouter = root
        appCoordinator = makeApp(root)
        appCoordinator.host = self
        root.transaction { [self] transaction in
            apply(snapshot, to: transaction)
        }
        sync()
    }

    /// Applies one link plan: the same shape as a snapshot, onto the current tree, in one transaction.
    @discardableResult
    public func open(_ plan: Snapshot) -> NavigationOutcome {
        let outcome = rootRouter.transaction { [self] transaction in
            transaction.dismissAll()
            apply(plan, to: transaction)
        }
        sync()
        return outcome
    }

    private func apply(_ snapshot: Snapshot, to transaction: NavigationTransaction) {
        let path = snapshot.path
        transaction.setPath {
            for route in path {
                route
            }
        }
        guard let route = snapshot.presentedRoute, let style = snapshot.presentedStyle else {
            return
        }
        if let factory = factories[route.routeKey] {
            factory.present(route, style, transaction)
        } else {
            screens[route.routeKey]?(route, style, transaction)
        }
        if let child = snapshot.presented.first, let next = transaction.presented {
            apply(child, to: next)
        }
    }

    public func encode(_ snapshot: Snapshot) throws -> Data {
        try JSONEncoder().encode(snapshot)
    }

    public func decode(_ data: Data) throws -> Snapshot {
        let decoder = JSONDecoder()
        decoder.userInfo[.routeRegistry] = registry
        return try decoder.decode(Snapshot.self, from: data)
    }
}
