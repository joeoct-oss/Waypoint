//
//  RouterTable+Tabs.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// Tab coordinators: each tab's child coordinator, and its router as the tab's stack.
extension RouterTable {
    /// The router of `coordinator`, made with its `makeRouter()` on the first read, with each
    /// tab's child coordinator's router as that tab's stack.
    func router<Coordinator: TabCoordinating>(of coordinator: Coordinator) -> TabRouter<Coordinator.Tab> {
        let id = ObjectIdentifier(coordinator)
        return resolve(
            coordinator,
            as: id,
            make: {
                coordinator.makeRouter()
            },
            standIn: { live in
                Self.inertTabRouter(like: live)
            },
            settle: { router in
                settleTabs(router, of: coordinator, as: id)
            }
        )
    }

    /// The router of `coordinator`, after checking that it is the table's: a stored router is
    /// reported, then adopted, and its tabs get their children. Waypoint calls this whenever it
    /// touches a tab coordinator.
    func checkedRouter<Coordinator: TabCoordinating>(
        of coordinator: Coordinator,
        file: StaticString,
        line: UInt
    ) -> TabRouter<Coordinator.Tab> {
        let router = coordinator.router
        let id = ObjectIdentifier(coordinator)
        if let entry = entry(for: id), entry.coordinator === coordinator, entry.router === router {
            return router
        }
        guard Self.isAlive(coordinator) else {
            return router
        }
        sweep()
        if let owner = liveOwner(of: router, other: coordinator) {
            store(Entry(coordinator: coordinator, router: router, ownsRouter: false), as: id)
            router.reportRouterOwned(by: owner, heldBy: coordinator, from: .stored, file: file, line: line)
            return router
        }
        router.reportRouterNotFromWaypoint(storedIn: coordinator, file: file, line: line)
        settleTabs(router, of: coordinator, as: id)
        return router
    }

    /// A tab router whose calls return `.ignored`, with the tabs of `live`.
    static func inertTabRouter<Tab: NavigationTab>(like live: TabRouter<Tab>) -> TabRouter<Tab> {
        let router = TabRouter(tabs: live.state.tabs, selection: live.selection)
        router.detachSubtree()
        return router
    }

    /// Keeps `router` as the router of `coordinator`, then asks for each tab's child: the
    /// selected tab first with ``TabStacks/shared``. The entry is stored first, so a child that
    /// reads its parent's router gets this one.
    func settleTabs<Coordinator: TabCoordinating>(
        _ router: TabRouter<Coordinator.Tab>,
        of coordinator: Coordinator,
        as id: ObjectIdentifier
    ) {
        let entry = Entry(coordinator: coordinator, router: router, ownsRouter: true)
        store(entry, as: id)
        router.setCoordinator(coordinator)
        let tabs = router.state.tabs
        let selected = router.stacks == .shared ? tabs.filter { $0 == router.selection } : []
        let rest = tabs.filter { !selected.contains($0) }
        attachChildren(of: coordinator, for: selected + rest, to: router, in: entry)
        router.onTabsChanged { [weak self, weak coordinator, weak entry, weak router] added, removed in
            guard let self, let coordinator, let entry, let router else {
                return
            }
            self.detachChildren(of: removed, from: router, in: entry)
            self.attachChildren(of: coordinator, for: added, to: router, in: entry)
        }
    }

    /// Asks `coordinator` for the child of each tab in `tabs`, keeps it, and makes its router
    /// the tab's stack.
    private func attachChildren<Coordinator: TabCoordinating>(
        of coordinator: Coordinator,
        for tabs: [Coordinator.Tab],
        to router: TabRouter<Coordinator.Tab>,
        in entry: Entry
    ) {
        for tab in tabs {
            let child = coordinator.coordinator(for: tab)
            if entry.children.values.contains(where: { $0 === child }) {
                router.router(for: tab).reportCoordinatorDrawnTwice(child, for: tab)
                continue
            }
            entry.keepChild(child, for: AnyHashable(tab))
            attach(child, as: tab, to: router)
        }
    }

    /// Makes the router of `child` the stack of `tab`: adopted when it can join, merged into a
    /// shared stack another tab already brought, or into a tab stack that already has screens,
    /// such as one the child pushed on in `init`, or refused and reported.
    private func attach<Tab: NavigationTab>(_ child: any StackCoordinating, as tab: Tab, to router: TabRouter<Tab>) {
        let childRouter = checkedRouter(of: child, file: #fileID, line: #line)
        let tabStack = router.router(for: tab)
        guard entry(for: ObjectIdentifier(child))?.ownsRouter == true else {
            return
        }
        router.nameTabCoordinator(ViewTypeName.of(type(of: child)), for: tab)
        if childRouter === tabStack {
            return
        }
        if childRouter.parentNode === router, !childRouter.isActive {
            restart(child, on: tabStack)
            return
        }
        guard childRouter.canJoinAnotherTree else {
            tabStack.reportRouterInAnotherTree(of: child, for: tab)
            return
        }
        let standInHasScreens = !tabStack.state.path.isEmpty || tabStack.presented != nil
        if standInHasScreens || (router.stacks == .shared && liveOwner(of: tabStack, other: child) != nil) {
            merge(child, router: childRouter, into: tabStack, for: tab)
            if router.stacks == .perTab {
                tabStack.setCoordinator(child)
            }
        } else {
            router.adoptTabRouter(childRouter, for: tab)
            nameTabStack(childRouter, of: child)
        }
    }

    /// Sends the calls of `child`'s router to `shared`, the tab's stack that another tab's child
    /// already brought or that already has screens, and registers the child's destinations there.
    private func merge<Tab: NavigationTab>(
        _ child: any StackCoordinating,
        router childRouter: StackRouter,
        into shared: StackRouter,
        for tab: Tab
    ) {
        shared.tree.takeOver(childRouter.tree)
        if !childRouter.state.path.isEmpty || childRouter.presented != nil {
            shared.reportTabChildRouterMerged(child, for: tab)
        }
        childRouter.forward(to: shared)
        store(Entry(coordinator: child, router: shared, ownsRouter: false), as: ObjectIdentifier(child))
        child.registerDestinations(on: shared)
    }

    /// Gives `child`, kept by the app and returned again for a tab added back, the tab's new
    /// stack: its old router left the tree with the removed tab. Navigators of the old router
    /// stay stale, as for any removed tab.
    private func restart<Child: StackCoordinating>(_ child: Child, on stack: StackRouter) {
        settle(stack, of: child, as: ObjectIdentifier(child), from: .made)
        nameTabStack(stack, of: child)
    }

    /// Names a tab's adopted stack: a child that keeps its type's default root name leaves the
    /// root screen to be named after its tab.
    private func nameTabStack(_ router: StackRouter, of child: any StackCoordinating) {
        guard child.rootName == Self.typeRootName(of: type(of: child)) else {
            return
        }
        router.clearRootScreenName()
    }

    /// Lets go of the children of removed tabs, after the table is updated.
    private func detachChildren<Tab: NavigationTab>(of tabs: [Tab], from router: TabRouter<Tab>, in entry: Entry) {
        let removed = tabs.compactMap { tab in
            router.forgetTabCoordinator(for: tab)
            return entry.takeChild(for: AnyHashable(tab))
        }
        withExtendedLifetime(removed) { }
    }
}
