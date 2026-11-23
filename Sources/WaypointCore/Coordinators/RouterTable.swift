//
//  RouterTable.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// The routers of the app's coordinators, so a coordinator needs no stored router.
///
/// A coordinator's router is made the first time it is read, named after the coordinator and
/// given the coordinator's destinations. A tab coordinator's router also hands each tab's child
/// coordinator its stack. The table holds each coordinator weakly and its router strongly, keyed
/// by the coordinator's identity, and a tab coordinator's entry keeps its children. At each read
/// and before each navigation call that isn't queued, it sweeps: an entry whose coordinator is
/// gone is removed, with the children it keeps, and its router is made inert, so its calls
/// return `.ignored` and log `staleNavigator`, unless a live entry still holds it, itself or
/// inside its tree. A router ends with its coordinator: one handed to a later coordinator is
/// reported as `releasedRouterReturned`.
///
/// Removed entries and children are let go only after the table is updated, so any `deinit`
/// that runs then finds a consistent table.
@MainActor
final class RouterTable {
    /// One coordinator's router, and a tab coordinator's children.
    final class Entry {
        /// The coordinator, held weakly so the table never keeps it alive.
        weak let coordinator: AnyObject?

        /// The coordinator's router: a `StackRouter` or a `TabRouter`.
        let router: any TreeNode

        /// Whether the router is the coordinator's own. `false` for a stored router another
        /// coordinator owns, which the table only remembers so it reports it once.
        let ownsRouter: Bool

        /// A tab coordinator's child coordinators, by tab, held strongly so they live as long as
        /// the tab coordinator does.
        ///
        /// `var` because tabs are added and removed. Only `keepChild(_:for:)` and
        /// `takeChild(for:)` change it.
        private(set) var children: [AnyHashable: AnyObject] = [:]

        /// Creates an entry for `coordinator`.
        init(coordinator: AnyObject, router: any TreeNode, ownsRouter: Bool) {
            self.coordinator = coordinator
            self.router = router
            self.ownsRouter = ownsRouter
        }

        /// Keeps `child` as the coordinator of `tab`.
        func keepChild(_ child: AnyObject, for tab: AnyHashable) {
            children[tab] = child
        }

        /// Stops keeping the child of `tab`, and returns it so the caller lets it go after the
        /// table is updated.
        func takeChild(for tab: AnyHashable) -> AnyObject? {
            children.removeValue(forKey: tab)
        }
    }

    /// Where a router the table settles came from.
    enum Source {
        /// `makeRouter()`, the default or the app's own.
        case made
        /// A router the coordinator stores, found when Waypoint touched it.
        case stored
    }

    /// The table the coordinator protocols' defaults use.
    static let shared = RouterTable()

    /// Each coordinator's entry, by the coordinator's identity.
    ///
    /// `var` because coordinators come and go. Only `store(_:as:)` and `sweep()` change it.
    private var entries: [ObjectIdentifier: Entry] = [:]

    /// Whether a sweep is removing entries, so a sweep started meanwhile does nothing.
    ///
    /// `var` because it is set for the length of one sweep. Only `sweep()` changes it.
    private var isSweeping = false

    /// Creates an empty table. The app uses ``shared``; tests make their own.
    init() { }

    /// The root name a coordinator type gets by default: its name without `Coordinator`.
    static func typeRootName(of type: Any.Type) -> String {
        let name = ViewTypeName.of(type)
        let suffix = "Coordinator"
        guard name.hasSuffix(suffix), name.count > suffix.count else {
            return name
        }
        return String(name.dropLast(suffix.count))
    }

    /// Whether a new weak reference to `object` reads it back. One formed while `object` is in
    /// its `deinit` reads `nil`.
    static func isAlive(_ object: AnyObject) -> Bool {
        weak let probe = object
        return probe != nil
    }

    /// The router of `coordinator`, made with its `makeRouter()` on the first read.
    func router<Coordinator: StackCoordinating>(of coordinator: Coordinator) -> StackRouter {
        router(of: coordinator, identifiedAs: ObjectIdentifier(coordinator))
    }

    /// The router of `coordinator`, whose entry is kept under `id`.
    ///
    /// The entry is looked up before the sweep. A coordinator whose entry holds it gets its
    /// router. Otherwise a new weak reference tells a coordinator going away, whose `deinit`
    /// reads its router, from one that took a freed coordinator's identity: the first gets an
    /// inert router, the second a fresh entry.
    func router<Coordinator: StackCoordinating>(
        of coordinator: Coordinator,
        identifiedAs id: ObjectIdentifier
    ) -> StackRouter {
        resolve(
            coordinator,
            as: id,
            make: {
                coordinator.makeRouter()
            },
            standIn: { _ in
                StackRouter.inert()
            },
            settle: { router in
                settle(router, of: coordinator, as: id, from: .made)
            }
        )
    }

    /// The router of `coordinator`, after checking that it is the table's: a stored router is
    /// reported, then adopted, named and registered, or, when another coordinator owns it, only
    /// reported. A router a tab container merged into its shared stack counts as the table's.
    /// Waypoint calls this whenever it touches a coordinator.
    func checkedRouter<Coordinator: StackCoordinating>(
        of coordinator: Coordinator,
        file: StaticString,
        line: UInt
    ) -> StackRouter {
        let router = coordinator.router
        let id = ObjectIdentifier(coordinator)
        if let entry = entries[id], entry.coordinator === coordinator {
            if entry.router === router || router.forwardTarget === entry.router {
                return router
            }
        }
        guard Self.isAlive(coordinator) else {
            return router
        }
        sweep()
        settle(router, of: coordinator, as: id, from: .stored, file: file, line: line)
        return router
    }

    /// The router kept under `id`, for tests.
    func entryRouter(for id: ObjectIdentifier) -> (any TreeNode)? {
        entries[id]?.router
    }

    /// The entry kept under `id`.
    func entry(for id: ObjectIdentifier) -> Entry? {
        entries[id]
    }

    /// Removes every entry whose coordinator is gone, with the children it keeps, and makes its
    /// router inert unless a live entry still holds it. The removed entries are let go after the
    /// table is updated.
    func sweep() {
        guard !isSweeping, entries.values.contains(where: \.isDead) else {
            return
        }
        isSweeping = true
        let removed = entries.filter { _, entry in
            entry.isDead
        }
        for id in removed.keys {
            entries.removeValue(forKey: id)
        }
        for entry in removed.values where !isHeldByLiveEntry(entry.router) {
            entry.router.detachSubtree()
        }
        isSweeping = false
        withExtendedLifetime(removed) { }
    }

    /// Looks up, or makes and settles, the router of `coordinator` under `id`.
    func resolve<Coordinator: AnyObject, Router: TreeNode>(
        _ coordinator: Coordinator,
        as id: ObjectIdentifier,
        make: () -> Router,
        standIn: (Router) -> Router,
        settle: (Router) -> Void
    ) -> Router {
        let found = entries[id]
        if let found, found.coordinator === coordinator, let router = found.router as? Router {
            sweep()
            return router
        }
        guard Self.isAlive(coordinator) else {
            return inertRouter(leftIn: found, make: make, standIn: standIn)
        }
        sweep()
        let router = make()
        settle(router)
        return router
    }

    /// Keeps `router` as the router of `coordinator`, names it and registers the coordinator's
    /// destinations on it. The coordinator's `rootName`, declared or the default, replaces any
    /// root name the router came with; a different name `makeRouter()` set is reported.
    /// When another coordinator owns the router, it reports that and leaves it.
    func settle<Coordinator: StackCoordinating>(
        _ router: StackRouter,
        of coordinator: Coordinator,
        as id: ObjectIdentifier,
        from source: Source,
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        if let owner = liveOwner(of: router, other: coordinator) {
            store(Entry(coordinator: coordinator, router: router, ownsRouter: false), as: id)
            router.reportRouterOwned(by: owner, heldBy: coordinator, from: source, file: file, line: line)
            return
        }
        store(Entry(coordinator: coordinator, router: router, ownsRouter: true), as: id)
        if !router.isActive {
            router.reportReleasedRouterReturned(to: coordinator, from: source, file: file, line: line)
        }
        if source == .stored {
            router.reportRouterNotFromWaypoint(storedIn: coordinator, file: file, line: line)
        }
        router.setCoordinator(coordinator)
        let rootName = coordinator.rootName
        if source == .made, let earlier = router.rootName, earlier != rootName {
            router.reportRootNameReplaced(earlier, by: rootName, of: coordinator, file: file, line: line)
        }
        router.setRootName(rootName)
        coordinator.registerDestinations(on: router)
    }

    /// Stores `entry` under `id`. An entry it replaces is let go after the table is updated.
    func store(_ entry: Entry, as id: ObjectIdentifier) {
        let replaced = entries.updateValue(entry, forKey: id)
        withExtendedLifetime(replaced) { }
    }

    /// The live coordinator, other than `coordinator`, whose own router `router` is.
    func liveOwner(of router: any TreeNode, other coordinator: AnyObject) -> AnyObject? {
        for entry in entries.values where entry.ownsRouter && entry.router === router {
            if let owner = entry.coordinator, owner !== coordinator {
                return owner
            }
        }
        return nil
    }

    /// Whether an entry whose coordinator is alive holds `router`, as its router or inside its
    /// router's tree, such as a tab container's stacks.
    func isHeldByLiveEntry(_ router: any TreeNode) -> Bool {
        entries.values.contains { entry in
            !entry.isDead && entry.router.contains(router)
        }
    }

    /// The router a coordinator going away reads: never stored, named, registered or joined.
    /// Its own router, made inert, unless a live entry still holds that router; then a stand-in,
    /// so the live router is left as it is.
    private func inertRouter<Router: TreeNode>(
        leftIn found: Entry?,
        make: () -> Router,
        standIn: (Router) -> Router
    ) -> Router {
        sweep()
        let router = (found?.router as? Router) ?? make()
        guard !isHeldByLiveEntry(router) else {
            return standIn(router)
        }
        router.detachSubtree()
        return router
    }
}

extension RouterTable.Entry {
    /// Whether the coordinator is gone.
    var isDead: Bool {
        coordinator == nil
    }
}

extension TreeNode {
    /// Whether `node` is this router or one inside its tree.
    func contains(_ node: any TreeNode) -> Bool {
        self === node || childNodes.contains { child in
            child.contains(node)
        }
    }
}
