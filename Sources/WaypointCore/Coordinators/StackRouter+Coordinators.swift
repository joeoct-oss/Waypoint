//
//  StackRouter+Coordinators.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

extension StackRouter {
    /// A router whose calls return `.ignored` and log `staleNavigator`, for a coordinator going
    /// away whose own router is still in use.
    static func inert() -> StackRouter {
        let router = StackRouter()
        router.markDetached()
        return router
    }

    /// Reports `releasedRouterReturned`: `coordinator` got this router from its `makeRouter()`
    /// or stores it, but the router ended with the coordinator it belonged to, so its calls
    /// return `.ignored`.
    func reportReleasedRouterReturned(
        to coordinator: AnyObject,
        from source: RouterTable.Source,
        file: StaticString,
        line: UInt
    ) {
        let name = ViewTypeName.of(type(of: coordinator))
        let how = source == .made ? "\(name).makeRouter() returned" : "\(name) stores"
        let message = "\(how) a router whose coordinator is gone. A router ends with its "
            + "coordinator, so this one ignores every call. Give each coordinator a new router: "
            + "make one in makeRouter() each time it is called."
        let issue = NavigationIssue(
            kind: .releasedRouterReturned,
            flow: flowID,
            message: message,
            file: file,
            line: line
        )
        tree.report(issue, level: .error)
    }

    /// Reports `rootNameReplaced`: the root name `makeRouter()` gave this router, `earlier`, is
    /// replaced by the coordinator's `rootName`.
    func reportRootNameReplaced(
        _ earlier: String,
        by rootName: String,
        of coordinator: AnyObject,
        file: StaticString,
        line: UInt
    ) {
        let name = ViewTypeName.of(type(of: coordinator))
        let message = "\(name).makeRouter() named the root screen \"\(earlier)\", and \(name).rootName "
            + "names it \"\(rootName)\" instead. Name the root screen with rootName, not in makeRouter()."
        let issue = NavigationIssue(kind: .rootNameReplaced, flow: flowID, message: message, file: file, line: line)
        tree.report(issue, level: .error)
    }

    /// Reports `coordinatorDrawnTwice`: the tab coordinator returned `child` for `tab` too, after
    /// another tab. This tab, whose stack this router is, keeps a stack of its own.
    func reportCoordinatorDrawnTwice<Tab: NavigationTab>(
        _ child: AnyObject,
        for tab: Tab,
        file: StaticString,
        line: UInt
    ) {
        let name = ViewTypeName.of(type(of: child))
        let tabName = DescriptionFormat.name(of: tab)
        let isShared = parentNode?.sharedStackTabName != nil
        let result = isShared
            ? "\(tabName) keeps no coordinator of its own and shows the tabs' shared stack"
            : "\(tabName) keeps a stack of its own, with none of \(name)'s destinations"
        let message = "The tab coordinator returned the same \(name) for the \(tabName) tab as for "
            + "an earlier tab. One coordinator drives one tab, so \(result). Return a different "
            + "coordinator for each tab."
        report(.coordinatorDrawnTwice, message, file: file, line: line)
    }

    /// Reports `routerInAnotherTree`: `child`'s router is already in another tree, so it can't
    /// become the stack of `tab`, which keeps this router.
    func reportRouterInAnotherTree<Tab: NavigationTab>(
        of child: AnyObject,
        for tab: Tab,
        file: StaticString,
        line: UInt
    ) {
        let name = ViewTypeName.of(type(of: child))
        let tabName = DescriptionFormat.name(of: tab)
        let isShared = parentNode?.sharedStackTabName != nil
        let result = isShared
            ? "The tab shows the tabs' shared stack, with none of \(name)'s destinations"
            : "The tab keeps a stack of its own, with none of \(name)'s destinations"
        let message = "\(name), the \(tabName) tab's coordinator, has a router that is already in "
            + "another tree, such as a presented flow's or another tab's, so it can't be the "
            + "\(tabName) tab's stack. \(result). Make a new router in \(name).makeRouter()."
        report(.routerInAnotherTree, message, file: file, line: line)
    }

    /// Reports `tabChildRouterMerged`: `child`, the coordinator of `tab`, pushed or presented on
    /// its own router before it joined, and the tab's stack, this router, is kept instead: the
    /// tabs' shared stack, or a tab stack that already had screens. Those screens are dropped.
    func reportTabChildRouterMerged<Tab: NavigationTab>(
        _ child: AnyObject,
        for tab: Tab,
        file: StaticString,
        line: UInt
    ) {
        let name = ViewTypeName.of(type(of: child))
        let tabName = DescriptionFormat.name(of: tab)
        let isShared = parentNode?.sharedStackTabName != nil
        let stack = isShared ? "the tabs' shared stack" : "the \(tabName) tab's stack, which already had screens"
        let message = "\(name), the \(tabName) tab's coordinator, pushed or presented on its own "
            + "router before it joined \(stack). Its calls go to that stack from now on, and those "
            + "screens are dropped. Navigate after the tab coordinator's router is read, not in init."
        report(.tabChildRouterMerged, message, file: file, line: line)
    }

    /// Reports an issue of `kind` on this router's flow, as an error.
    private func report(_ kind: NavigationIssue.Kind, _ message: String, file: StaticString, line: UInt) {
        let issue = NavigationIssue(kind: kind, flow: flowID, message: message, file: file, line: line)
        tree.report(issue, level: .error)
    }
}

/// Reports shared by stack and tab routers.
extension TreeNode {
    /// Reports `routerNotFromWaypoint`: `coordinator` stores this router instead of taking the
    /// one Waypoint makes. Waypoint adopts it from now on.
    func reportRouterNotFromWaypoint(storedIn coordinator: AnyObject, file: StaticString, line: UInt) {
        let name = ViewTypeName.of(type(of: coordinator))
        let stackMessage = "\(name) stores its router instead of taking the one Waypoint makes. Waypoint "
            + "uses it from now on, but calls made before now could fail with unregisteredRoute, and "
            + "its root screen is now named by rootName. Remove the stored router, implement "
            + "makeRouter() to make one of your own, and name the root with rootName."
        let tabMessage = "\(name) stores its router instead of taking the one Waypoint makes. Waypoint "
            + "uses it from now on and gives each tab its coordinator's stack, but calls made on it "
            + "before now went around Waypoint. Remove the stored router and implement makeRouter()."
        let message = self is StackRouter ? stackMessage : tabMessage
        let issue = NavigationIssue(
            kind: .routerNotFromWaypoint,
            flow: flowID,
            message: message,
            file: file,
            line: line
        )
        tree.report(issue, level: .error)
    }

    /// Reports `routerOwnedByAnotherCoordinator`: `coordinator` stores this router, or its
    /// `makeRouter()` returns it, and `owner` owns it. Waypoint leaves it as it is: not adopted,
    /// renamed or registered on, so the coordinator's own routes stay unregistered.
    func reportRouterOwned(
        by owner: AnyObject,
        heldBy coordinator: AnyObject,
        from source: RouterTable.Source,
        file: StaticString,
        line: UInt
    ) {
        let name = ViewTypeName.of(type(of: coordinator))
        let ownerName = ViewTypeName.of(type(of: owner))
        let how = source == .made ? "makeRouter() returns" : "stores"
        let fix = source == .made
            ? "make a new router in makeRouter()"
            : "remove the stored router, or implement makeRouter()"
        let text = "\(name) \(how) the router of \(ownerName), so both drive one stack. Waypoint "
            + "leaves it with \(ownerName) and registers none of \(name)'s destinations on it. Give "
            + "\(name) a router of its own: \(fix)."
        let issue = NavigationIssue(
            kind: .routerOwnedByAnotherCoordinator,
            flow: flowID,
            message: text,
            file: file,
            line: line
        )
        tree.report(issue, level: .error)
    }
}
