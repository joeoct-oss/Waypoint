//
//  Rejection+Issue.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

extension Rejection {
    /// The issue kind this rejection is reported as.
    var kind: NavigationIssue.Kind {
        switch self {
        case .emptyPath:
            return .emptyPath
        case .notEnoughRoutes:
            return .notEnoughRoutes
        case .routeNotInPath, .typeNotInPath:
            return .routeNotInPath
        case .unknownTab, .noTabs:
            return .unknownTab
        case .alreadyPresenting:
            return .alreadyPresenting
        }
    }

    /// Explains a pop on an empty path.
    private static func emptyPathMessage() -> String {
        "pop() was called on an empty path, so the root screen is already showing."
    }

    /// Explains a pop of too many routes.
    private static func notEnoughRoutesMessage(requested: Int, available: Int) -> String {
        "pop(count: \(requested)) asked for \(requested) routes, but the path holds \(available). "
            + "Use popToRoot() to go back to the root screen."
    }

    /// Explains a `popTo` route that is not in the path.
    private static func routeNotInPathMessage(_ route: AnyRoute, path: [AnyRoute], naming: RouteNaming) -> String {
        "\(naming.typeName(route.routeKey)) is not in the path \(naming.list(path)). "
            + "Check contains(_:) first, or handle the .failed outcome."
    }

    /// Explains a typed `popTo` with no match.
    private static func typeNotInPathMessage(_ key: RouteKey, path: [AnyRoute], naming: RouteNaming) -> String {
        "No \(naming.typeName(key)) in the path \(naming.list(path)) matches. "
            + "Check last(_:) first, or handle the .failed outcome."
    }

    /// Explains a tab that is not one of the tabs.
    private static func unknownTabMessage(_ name: String) -> String {
        "\(name) is not one of this container's tabs. Add it with setTabs(_:) first."
    }

    /// Explains an empty tab list.
    private static func noTabsMessage() -> String {
        "A tab container needs at least one tab, so setTabs(_:) with no tabs was refused."
    }

    /// Explains a second presentation.
    private static func alreadyPresentingMessage(_ flow: FlowID) -> String {
        "This flow already presents \(flow). Dismiss it first, or present from the presented flow."
    }

    /// What went wrong and how to fix it, with routes named as `naming` names them.
    func message(path: [AnyRoute], naming: RouteNaming) -> String {
        switch self {
        case .emptyPath:
            return Self.emptyPathMessage()
        case .notEnoughRoutes(let requested, let available):
            return Self.notEnoughRoutesMessage(requested: requested, available: available)
        case .routeNotInPath(let route):
            return Self.routeNotInPathMessage(route, path: path, naming: naming)
        case .typeNotInPath(let key):
            return Self.typeNotInPathMessage(key, path: path, naming: naming)
        case .unknownTab(let name):
            return Self.unknownTabMessage(name)
        case .noTabs:
            return Self.noTabsMessage()
        case .alreadyPresenting(let flow):
            return Self.alreadyPresentingMessage(flow)
        }
    }
}
