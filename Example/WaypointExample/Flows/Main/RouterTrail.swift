//
//  RouterTrail.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import WaypointCore

// Reads a screen's route trail from its stack router, so the trail is always the real path: the
// main tabs, the tab or the flow that presented the stack, then each route up to the screen, by
// its display name. A pushed product on Shop reads `main › shop › orbit lamp`.
//
// A stack presented from another stack starts with that stack's whole trail, so checkout reads
// `main › cart › checkout`. A stack with no router above it, such as a Lab demo, starts with its
// root name.
enum RouterTrail {
    static let tabsName = "main"
    private static let unnamedRoot = "flow"

    // The trail of the screen that shows `route` on `router`, or of the stack's root screen when
    // `route` is `nil`.
    static func steps(
        on router: StackRouter,
        at route: AnyRoute?
    ) -> [String] {
        let path = router.state.path
        // The last copy, so the screen on top reads its whole path when a route is on it twice.
        let end = route.flatMap { path.lastIndex(of: $0) }.map { $0 + 1 } ?? 0
        return rootSteps(of: router) + path.prefix(end).map(name(of:))
    }

    // Whether the screen is the root of a tab, or of a flow with nothing above it but the tabs.
    // Such a screen shows a large title and no trail.
    static func isRoot(
        on router: StackRouter,
        at route: AnyRoute?
    ) -> Bool {
        guard route == nil else {
            return false
        }
        return !(router.parent is StackRouter)
    }

    private static func rootSteps(of router: StackRouter) -> [String] {
        switch router.parent {
        case let tabs as TabRouter<MainTab>:
            return [tabsName, tabName(of: router, in: tabs)]
        case let presenter as StackRouter:
            return steps(on: presenter, at: presenter.state.path.last) + [rootName(of: router)]
        default:
            return [rootName(of: router)]
        }
    }

    // The tab the stack belongs to, or the flow's own name when the tabs present it.
    private static func tabName(
        of router: StackRouter,
        in tabs: TabRouter<MainTab>
    ) -> String {
        // The tabs share one stack, so it belongs to the selected tab. A flow the tabs present
        // keeps its own name.
        guard tabs.stacks == .perTab else {
            let isSharedStack = router === tabs.router(for: tabs.selection)
            return isSharedStack ? tabs.selection.title.lowercased() : rootName(of: router)
        }
        let tab = tabs.state.tabs.first { tabs.router(for: $0) === router }
        return tab?.title.lowercased() ?? rootName(of: router)
    }

    // The presented route's name, else the name the coordinator gave the root.
    private static func rootName(of router: StackRouter) -> String {
        if let route = router.rootRoute {
            return name(of: route)
        }
        return router.rootName?.lowercased() ?? unnamedRoot
    }

    private static func name(of route: AnyRoute) -> String {
        for type in TrailStepTypes.all {
            if let name = name(of: route, as: type) {
                return name
            }
        }
        return readableName(of: route.routeKey.typeName)
    }

    private static func name<Step: TrailStep>(
        of route: AnyRoute,
        as type: Step.Type
    ) -> String? {
        route.as(type)?.trailName
    }

    // `ProductReviewsRoute` reads `product reviews`.
    private static func readableName(of typeName: String) -> String {
        let base = typeName.hasSuffix("Route") ? String(typeName.dropLast(5)) : typeName
        let words = base.reduce(into: "") { text, character in
            if character.isUppercase, !text.isEmpty {
                text.append(" ")
            }
            text.append(character)
        }
        return words.lowercased()
    }
}

// A route that names its step in the route trail.
//
// Conformances:
// - `Route`, so `RouterTrail` can find it in a router's path.
protocol TrailStep: Route {
    var trailName: String { get }
}

extension TrailStep where Self: TrackableScreen {
    // The journey's name for the screen, in lower case: the display name, else the screen name.
    var trailName: String {
        (screenDisplayName ?? Self.screenName).lowercased()
    }
}

// Every route the example app's trail names. A route left out reads by its type name.
enum TrailStepTypes {
    static let all: [any TrailStep.Type] = [
        ProductRoute.self,
        CollectionRoute.self,
        ShopCartRoute.self,
        FilterRoute.self,
        SavedRoute.self,
        WishlistRoute.self,
        CheckoutRoute.self,
        CheckoutStep.self,
        AddAddressRoute.self,
        OrderPlacedRoute.self,
        AccountRoute.self,
        CreateAccountRoute.self,
        TermsRoute.self,
        SignedInRoute.self,
        SheetDemoRoute.self,
        DetailProductRoute.self,
        DetailCartRoute.self,
    ]
}

// Conformances:
// - `TrailStep`, so the trail names the screen as the journey does.
extension ProductRoute: TrailStep { }
extension CollectionRoute: TrailStep { }
extension ShopCartRoute: TrailStep { }
extension FilterRoute: TrailStep { }
extension SavedRoute: TrailStep { }
extension WishlistRoute: TrailStep { }
extension CheckoutRoute: TrailStep { }
extension AddAddressRoute: TrailStep { }
extension OrderPlacedRoute: TrailStep { }
extension AccountRoute: TrailStep { }
extension CreateAccountRoute: TrailStep { }
extension TermsRoute: TrailStep { }
extension SignedInRoute: TrailStep { }
extension SheetDemoRoute: TrailStep { }

// Conformances:
// - `TrailStep`, so the trail names the step: `payment` or `review`.
extension CheckoutStep: TrailStep {
    var trailName: String {
        switch self {
        case .payment:
            return "payment"
        case .review:
            return "review"
        }
    }
}

// Conformances:
// - `TrailStep`, so the trail shows which product the Detail push story pushed.
extension DetailProductRoute: TrailStep {
    var trailName: String {
        "product \(productID)"
    }
}

// Conformances:
// - `TrailStep`, so the trail shows the cart the Detail push story pops back to.
extension DetailCartRoute: TrailStep {
    var trailName: String {
        "cart"
    }
}
