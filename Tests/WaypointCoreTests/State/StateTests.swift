//
//  StateTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Foundation
import Testing
import WaypointCore
import WaypointTestSupport

/// State values: saving, restoring, presentation styles and descriptions (#45, decision 0010).
@Suite("Navigation state")
struct StateTests {
    let filter = Presentation(style: .sheet, flow: FlowID("filter"), route: AnyRoute(SettingsRoute()))

    @Test
    func stateRoundTripsThroughCodable() throws {
        let stack = StackState(path: [AnyRoute(HomeRoute()), AnyRoute(ProductRoute(id: 4))], presentation: filter)
        let tabs = TabState(tabs: [MainTab.home, .shop], selection: .shop, presentation: filter)

        #expect(try roundTrip(stack) == stack)
        #expect(try roundTrip(tabs) == tabs)
    }

    @Test
    func presentationStylesRoundTrip() throws {
        let styles: [PresentationStyle] = [
            .sheet,
            .fullScreenCover,
            .sheet(detents: [.medium, .fraction(0.3), .height(240), .fitsContent, .custom("tall")], selected: .medium),
            .sheet(SheetOptions(detents: [.fitsContent], fitsContentLimit: .fraction(0.6), showsDragIndicator: true)),
        ]

        for style in styles {
            #expect(try roundTrip(Presentation(style: style, flow: FlowID("a"))).style == style)
        }
    }

    @Test
    func sheetOptionsDefaults() {
        let options = SheetOptions.default

        #expect(options.detents == [.large])
        #expect(options.selectedDetent == nil)
        #expect(options.fitsContentLimit == .large)
        #expect(options.showsDragIndicator == nil)
        #expect(options.allowsInteractiveDismiss)
        #expect(PresentationStyle.sheet.sheetOptions == nil)
        #expect(PresentationStyle.sheet(detents: [.medium]).sheetOptions?.detents == [.medium])
        #expect(PresentationStyle.fullScreenCover.isFullScreenCover)
    }

    @Test
    func stackStateDescription() {
        let state = StackState(path: [AnyRoute(HomeRoute()), AnyRoute(ProductRoute(id: 4))])

        #expect(state.description == "[HomeRoute, ProductRoute(id: <private>)]")
        #expect(state.debugDescription(revealingPrivateValues: true) == "[HomeRoute, ProductRoute(id: 4)]")
        #expect(StackState(presentation: filter).description == "[] + sheet SettingsRoute flow=filter")
    }

    @Test
    func tabStateDescriptionMarksSelection() {
        let state = TabState(tabs: [MainTab.home, .shop, .profile], selection: .shop)

        #expect(state.description == "[home, *shop, profile]")
    }

    @Test
    func presentationDescriptions() {
        let cover = Presentation(style: .fullScreenCover, flow: FlowID("login"))

        #expect(filter.description == "sheet SettingsRoute flow=filter")
        #expect(cover.description == "fullScreenCover flow=login")
        #expect(PresentationStyle.sheet(detents: [.medium, .large]).description == "sheet(detents: [medium, large])")
        #expect(PresentationStyle.sheet(detents: [.fraction(0.5), .height(200)]).description == "sheet(detents: [fraction(0.5), height(200.0)])")
        #expect(FlowID("shop").description == "shop")
    }

    @Test
    func changeDescriptions() {
        let product = AnyRoute(ProductRoute(id: 4))

        #expect(NavigationChange.pushed([product]).description == "pushed [ProductRoute(id: <private>)]")
        #expect(NavigationChange.popped([AnyRoute(HomeRoute())]).description == "popped [HomeRoute]")
        #expect(NavigationChange.replaced(from: [], to: [product]).description == "replaced [] -> [ProductRoute(id: <private>)]")
        #expect(NavigationChange.tabSelected(from: "home", to: "shop").description == "tabSelected home -> shop")
        #expect(NavigationChange.dismissed(FlowID("filter")).description == "dismissed flow=filter")
        #expect(NavigationChange.presented(filter).description == "presented sheet SettingsRoute flow=filter")
        #expect(NavigationChange.pushed([product]).debugDescription(revealingPrivateValues: true) == "pushed [ProductRoute(id: 4)]")
    }

    @Test
    func treeDescription() {
        let shop = NavigationTree(root: .stack(FlowID("shop"), StackState(path: [AnyRoute(ProductRoute(id: 1))], presentation: filter)))
        let tree = NavigationTree(
            root: .root(FlowID("app"), current: "main", child: NavigationTree(
                root: .tabs(FlowID("main"), selection: "shop", tabs: ["shop": shop])
            ))
        )

        #expect(tree.description == "root(app) current=main > tabs(main) selection=shop > stack(shop)[ProductRoute(id: <private>)] + sheet SettingsRoute flow=filter")
    }

    /// Encodes and decodes a value with a registry that knows the shared routes.
    private func roundTrip<Value: Codable>(_ value: Value) throws -> Value {
        var registry = RouteRegistry()
        registry.register(HomeRoute.self)
        registry.register(ProductRoute.self)
        registry.register(SettingsRoute.self)
        let decoder = JSONDecoder()
        decoder.userInfo[.routeRegistry] = registry
        return try decoder.decode(Value.self, from: JSONEncoder().encode(value))
    }
}
