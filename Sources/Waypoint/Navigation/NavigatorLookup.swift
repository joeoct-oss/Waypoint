//
//  NavigatorLookup.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// Not guarded by `canImport(SwiftUI)`: it uses only the core, so its rules are unit tested on
// Linux too. The property wrappers read the environment and call it.

import WaypointCore

/// How the property wrappers turn what the environment holds into a navigator.
///
/// When no matching router is above the view, the navigator they get fails every call with a
/// `noRouterInScope` issue that names the wrapper, the file and line where it is declared, and
/// the fix. Nothing crashes.
@MainActor
enum NavigatorLookup {
    /// The navigator of the nearest stack, for `@StackNavigation`.
    static func stack(
        _ router: StackRouter?,
        site: WrapperSite,
        report: @escaping @MainActor (NavigationIssue) -> Void
    ) -> StackNavigator {
        guard let router else {
            return StackNavigator(missing: missingStackMessage("@StackNavigation", site), report: report)
        }
        return router.rootScreenNavigator
    }

    /// The navigator of the nearest stack of `flow`, for `@FlowNavigation(flow)`.
    static func flow<Flow: NavigationFlow>(
        _ flow: Flow.Type,
        in routers: FlowRouters,
        site: WrapperSite,
        report: @escaping @MainActor (NavigationIssue) -> Void
    ) -> FlowNavigator<Flow> {
        guard let router = routers.router(for: flow) else {
            return FlowNavigator(missing: missingFlowMessage(flow, site), report: report)
        }
        return router.rootScreenNavigator(for: flow, file: site.file, line: site.line)
    }

    /// The action that dismisses the nearest stack's flow, for `@DismissFlow`.
    static func dismissFlow(
        _ router: StackRouter?,
        site: WrapperSite,
        report: @escaping @MainActor (NavigationIssue) -> Void
    ) -> DismissFlowAction {
        guard let router else {
            let navigator = StackNavigator(missing: missingStackMessage("@DismissFlow", site), report: report)
            return DismissFlowAction(navigator: navigator)
        }
        return DismissFlowAction(navigator: router.rootScreenNavigator)
    }

    /// The navigator a destination closure gets: one for the screen showing `route`, which does
    /// nothing once that screen is popped, or, outside a Waypoint stack, one that fails every
    /// call.
    static func destination<R: Route>(
        _ router: StackRouter?,
        route: R,
        report: @escaping @MainActor (NavigationIssue) -> Void
    ) -> StackNavigator {
        guard let router else {
            return StackNavigator(missing: missingDestinationMessage(R.self), report: report)
        }
        return router.navigator(forScreenShowing: AnyRoute(route))
    }

    /// Why a wrapper that needs any stack found none, and the fix.
    static func missingStackMessage(_ wrapper: String, _ site: WrapperSite) -> String {
        "\(wrapper) in \(site.callSite) found no Waypoint stack above its view. Show the view "
            + "inside a WaypointStack, or add .waypointPreview() in its preview."
    }

    /// Why a destination's navigator has no router, and the fix.
    static func missingDestinationMessage<R: Route>(_ route: R.Type) -> String {
        "destination(\(R.routeKey.typeName).self) is not inside a Waypoint stack, so its navigator has "
            + "no router. Register the destination on a screen inside a WaypointStack."
    }

    /// Why `@FlowNavigation` found no stack of its flow, and the fix.
    static func missingFlowMessage<Flow: NavigationFlow>(_ flow: Flow.Type, _ site: WrapperSite) -> String {
        "@FlowNavigation(\(flow).self) in \(site.callSite) found no \(flow) stack above its view. "
            + "Declare one with WaypointStack(flow: \(flow).self), or add "
            + ".waypointPreview(flow: \(flow).self) in its preview."
    }
}

/// Where a property wrapper is declared, so its issues point at the view.
///
/// Conformances:
/// - `Sendable`, so wrappers that hold it stay `Sendable` like SwiftUI's own.
struct WrapperSite: Sendable {
    /// The file of the declaration, as `#fileID` gives it.
    let file: StaticString

    /// The line of the declaration.
    let line: UInt

    /// The file name without its module, and the line: `ProductView.swift:12`.
    var callSite: String {
        let path = "\(file)"
        let name = path.split(separator: "/").last.map(String.init) ?? path
        return "\(name):\(line)"
    }
}
