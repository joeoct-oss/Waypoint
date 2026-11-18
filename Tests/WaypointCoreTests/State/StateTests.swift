//
//  StateTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Foundation
import Testing
import WaypointCore
import WaypointTestSupport

/// State values: saving, restoring, presentation styles and descriptions (#45, see the Descriptions
/// article).
@Suite("Navigation state")
struct StateTests {
    let filter = Presentation(style: .sheet, flow: FlowID("filter"), route: AnyRoute(SettingsRoute()))

    @Test
    func stateRoundTripsThroughCodable() throws {
        let path = [AnyRoute(HomeRoute()), AnyRoute(ProductRoute(id: 4))]
        let stack = StackState(path: path, presentation: filter)
        let tabs = TabState(tabs: MainTab.homeAndShop, selection: .shop, presentation: filter)

        #expect(try roundTrip(stack) == stack)
        #expect(try roundTrip(tabs) == tabs)
    }

    @Test
    func presentationStylesRoundTrip() throws {
        let everyDetent: [SheetDetent] = [.medium, .fraction(0.3), .height(240), .fitsContent, .custom("tall")]
        let fitted: [SheetDetent] = [.fitsContent]
        let fittedOptions = SheetOptions(detents: fitted, fitsContentLimit: .fraction(0.6), showsDragIndicator: true)
        let styles: [PresentationStyle] = [
            .sheet,
            .fullScreenCover,
            .sheet(detents: everyDetent, selected: .medium),
            .sheet(fittedOptions),
        ]

        for style in styles {
            #expect(try roundTrip(Presentation(style: style, flow: FlowID("a"))).style == style)
        }
    }

    @Test
    func sheetOptionsDefaults() {
        let options = SheetOptions.default
        let large: [SheetDetent] = [.large]
        let medium: [SheetDetent] = [.medium]

        #expect(options.detents == large)
        #expect(options.selectedDetent == nil)
        #expect(options.fitsContentLimit == .large)
        #expect(options.showsDragIndicator == nil)
        #expect(options.allowsInteractiveDismiss)
        #expect(PresentationStyle.sheet.sheetOptions == nil)
        #expect(PresentationStyle.sheet(detents: medium).sheetOptions?.detents == medium)
        #expect(PresentationStyle.fullScreenCover.isFullScreenCover)
    }

    @Test
    func stackStateDescription() {
        let path = [AnyRoute(HomeRoute()), AnyRoute(ProductRoute(id: 4))]
        let state = StackState(path: path)

        #expect(state.description == "[HomeRoute, ProductRoute(id: <private>)]")
        #expect(state.debugDescription(revealingPrivateValues: true) == "[HomeRoute, ProductRoute(id: 4)]")
        #expect(StackState(presentation: filter).description == "[] + sheet SettingsRoute flow=filter")
    }

    @Test
    func tabStateDescriptionMarksSelection() {
        let state = TabState(tabs: MainTab.allCases, selection: .shop)

        #expect(state.description == "[home, *shop, profile]")
    }

    @Test
    func presentationDescriptions() {
        let cover = Presentation(style: .fullScreenCover, flow: FlowID("login"))
        let mediumAndLarge: [SheetDetent] = [.medium, .large]
        let sizes: [SheetDetent] = [.fraction(0.5), .height(200)]
        let resizable = PresentationStyle.sheet(detents: mediumAndLarge)
        let sized = PresentationStyle.sheet(detents: sizes)

        #expect(filter.description == "sheet SettingsRoute flow=filter")
        #expect(cover.description == "fullScreenCover flow=login")
        #expect(resizable.description == "sheet(detents: [medium, large])")
        #expect(sized.description == "sheet(detents: [fraction(0.5), height(200.0)])")
        #expect(FlowID("shop").description == "shop")
    }

    @Test
    func changeDescriptions() {
        let products = [AnyRoute(ProductRoute(id: 4))]
        let homes = [AnyRoute(HomeRoute())]
        let empty: [AnyRoute] = []
        let pushed = NavigationChange.pushed(products)
        let replaced = NavigationChange.replaced(from: empty, to: products)

        #expect(pushed.description == "pushed [ProductRoute(id: <private>)]")
        #expect(NavigationChange.popped(homes).description == "popped [HomeRoute]")
        #expect(replaced.description == "replaced [] -> [ProductRoute(id: <private>)]")
        #expect(NavigationChange.tabSelected(from: "home", to: "shop").description == "tabSelected home -> shop")
        #expect(NavigationChange.dismissed(FlowID("filter")).description == "dismissed flow=filter")
        #expect(NavigationChange.presented(filter).description == "presented sheet SettingsRoute flow=filter")
        #expect(pushed.debugDescription(revealingPrivateValues: true) == "pushed [ProductRoute(id: 4)]")
    }

    @Test
    func treeDescription() {
        let shopPath = [AnyRoute(ProductRoute(id: 1))]
        let shopState = StackState(path: shopPath, presentation: filter)
        let shop = NavigationTree(root: .stack(FlowID("shop"), shopState))
        let tabTrees = ["shop": shop]
        let main = NavigationTree(root: .tabs(FlowID("main"), selection: "shop", tabs: tabTrees))
        let tree = NavigationTree(root: .root(FlowID("app"), current: "main", child: main))

        let expected = "root(app) current=main > tabs(main) selection=shop > "
            + "stack(shop)[ProductRoute(id: <private>)] + sheet SettingsRoute flow=filter"
        #expect(tree.description == expected)
    }

    // Encodes and decodes a value with a registry that knows the shared routes.
    private func roundTrip<Value: Codable>(_ value: Value) throws -> Value {
        let registry = RouteRegistry()
            .registering(HomeRoute.self)
            .registering(ProductRoute.self)
            .registering(SettingsRoute.self)
        let decoder = JSONDecoder()
        decoder.userInfo[.routeRegistry] = registry
        return try decoder.decode(Value.self, from: JSONEncoder().encode(value))
    }
}
