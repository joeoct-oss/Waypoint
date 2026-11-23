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
/// given the coordinator's destinations. The table holds each coordinator weakly and its router
/// strongly, keyed by the coordinator's identity. At each read and before each navigation call
/// that isn't queued, it sweeps: an entry whose coordinator is gone is removed, and a router the
/// table made for it is made inert, so its calls return `.ignored` and log `staleNavigator`,
/// unless a live entry still holds it. A stored router the table adopted stays live, since the
/// app made it and may still use it.
///
/// Removed entries are let go only after the table is updated, so any `deinit` that runs then
/// finds a consistent table.
@MainActor
final class RouterTable {
    /// One coordinator's router.
    final class Entry {
        /// The coordinator, held weakly so the table never keeps it alive.
        weak let coordinator: AnyObject?

        /// The coordinator's router.
        let router: StackRouter

        /// Whether the router is the coordinator's own. `false` for a stored router another
        /// coordinator owns, which the table only remembers so it reports it once.
        let ownsRouter: Bool

        /// Whether the table made the router with `makeRouter()`. Only such a router is made
        /// inert when its coordinator is gone; a stored one belongs to the app, which may still
        /// use it.
        let isMade: Bool

        /// Creates an entry for `coordinator`.
        init(coordinator: AnyObject, router: StackRouter, ownsRouter: Bool, isMade: Bool) {
            self.coordinator = coordinator
            self.router = router
            self.ownsRouter = ownsRouter
            self.isMade = isMade
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
        let found = entries[id]
        if let found, found.coordinator === coordinator {
            sweep()
            return found.router
        }
        guard Self.isAlive(coordinator) else {
            return inertRouter(for: coordinator, leftIn: found)
        }
        sweep()
        let router = coordinator.makeRouter()
        settle(router, of: coordinator, as: id, from: .made)
        return router
    }

    /// The router of `coordinator`, after checking that it is the table's: a stored router is
    /// reported, then adopted, named and registered, or, when another coordinator owns it, only
    /// reported. Waypoint calls this whenever it touches a coordinator.
    func checkedRouter<Coordinator: StackCoordinating>(
        of coordinator: Coordinator,
        file: StaticString,
        line: UInt
    ) -> StackRouter {
        let router = coordinator.router
        let id = ObjectIdentifier(coordinator)
        if let entry = entries[id], entry.coordinator === coordinator, entry.router === router {
            return router
        }
        guard Self.isAlive(coordinator) else {
            return router
        }
        sweep()
        settle(router, of: coordinator, as: id, from: .stored, file: file, line: line)
        return router
    }

    /// The router kept under `id`, for tests.
    func entryRouter(for id: ObjectIdentifier) -> StackRouter? {
        entries[id]?.router
    }

    /// Removes every entry whose coordinator is gone, and makes a router the table made for it
    /// inert unless a live entry still holds it. The removed entries are let go after the table
    /// is updated.
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
        for entry in removed.values where entry.isMade && !isHeldByLiveEntry(entry.router) {
            entry.router.detachSubtree()
        }
        isSweeping = false
        withExtendedLifetime(removed) { }
    }

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
    private static func isAlive(_ object: AnyObject) -> Bool {
        weak let probe = object
        return probe != nil
    }

    /// Keeps `router` as the router of `coordinator`, names it and registers the coordinator's
    /// destinations on it. The coordinator's `rootName`, declared or the default, replaces any
    /// root name the router came with.
    /// When another coordinator owns the router, it reports that and leaves it.
    private func settle<Coordinator: StackCoordinating>(
        _ router: StackRouter,
        of coordinator: Coordinator,
        as id: ObjectIdentifier,
        from source: Source,
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        if let owner = liveOwner(of: router, other: coordinator) {
            store(Entry(coordinator: coordinator, router: router, ownsRouter: false, isMade: false), as: id)
            router.reportRouterOwned(by: owner, heldBy: coordinator, from: source, file: file, line: line)
            return
        }
        let entry = Entry(coordinator: coordinator, router: router, ownsRouter: true, isMade: source == .made)
        store(entry, as: id)
        if source == .stored {
            router.reportRouterNotFromWaypoint(storedIn: coordinator, file: file, line: line)
        }
        router.setCoordinator(coordinator)
        router.setRootName(coordinator.rootName)
        coordinator.registerDestinations(on: router)
    }

    /// Stores `entry` under `id`. An entry it replaces is let go after the table is updated.
    private func store(_ entry: Entry, as id: ObjectIdentifier) {
        let replaced = entries.updateValue(entry, forKey: id)
        withExtendedLifetime(replaced) { }
    }

    /// The router a coordinator going away reads: never stored, named, registered or joined.
    /// Its own router, made inert, unless a live entry still holds that router or the router is a
    /// stored one the app made; then a fresh inert one, so that router is left as it is.
    private func inertRouter<Coordinator: StackCoordinating>(
        for coordinator: Coordinator,
        leftIn found: Entry?
    ) -> StackRouter {
        sweep()
        if let found, !found.isMade {
            return StackRouter.inert()
        }
        let router = found?.router ?? coordinator.makeRouter()
        guard !isHeldByLiveEntry(router) else {
            return StackRouter.inert()
        }
        router.detachSubtree()
        return router
    }

    /// The live coordinator, other than `coordinator`, whose own router `router` is.
    private func liveOwner(of router: StackRouter, other coordinator: AnyObject) -> AnyObject? {
        for entry in entries.values where entry.ownsRouter && entry.router === router {
            if let owner = entry.coordinator, owner !== coordinator {
                return owner
            }
        }
        return nil
    }

    /// Whether an entry whose coordinator is alive holds `router`.
    private func isHeldByLiveEntry(_ router: StackRouter) -> Bool {
        entries.values.contains { entry in
            !entry.isDead && entry.router === router
        }
    }
}

extension RouterTable.Entry {
    /// Whether the coordinator is gone.
    var isDead: Bool {
        coordinator == nil
    }
}
