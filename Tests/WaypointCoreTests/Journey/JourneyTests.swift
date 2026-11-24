//
//  JourneyTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Foundation
import Testing
import WaypointTestSupport

@testable import WaypointCore

/// The journey (#216, #239): the screen on display after each change across tabs, stacks and
/// presentations, its visit with the previous screen and the source, and the box each change
/// writes.
@Suite("Journey")
@MainActor
struct JourneyTests {
    private typealias ItemRoute = JourneyFixtures.ItemRoute
    private typealias ProductListRoute = JourneyFixtures.ProductListRoute

    @Test
    func aPushVisitsTheScreenOnTop() throws {
        let handler = RecordingLogHandler()
        let router = JourneyFixtures.stack(handler, clock: JourneyFixtures.ManualClock())
        router.setRootName("Product list")

        router.push(ItemRoute(id: 3, title: "Orbit Lamp"))

        let visit = try #require(router.screenVisit)
        #expect(visit.screen.title == "Product 3")
        #expect(visit.screen.displayName == "Orbit Lamp")
        #expect(visit.screen.description == "Product 3 \"Orbit Lamp\"")
        #expect(visit.previous == nil)
        #expect(visit.source.title == "Product list")
        #expect(visit.transition == .push)
        #expect(visit.origin == .app)
        #expect(visit.callSite?.hasPrefix("JourneyTests.swift:") == true)
        let journey = visit.journey.map(\.title)
        let expectedJourney = [
            "Product list",
            "Product 3",
        ]
        #expect(journey == expectedJourney)
        #expect(visit.depth == 1)
    }

    @Test
    func aStackAppearingVisitsItsFirstScreenOnce() throws {
        let handler = RecordingLogHandler()
        let router = JourneyFixtures.stack(handler, clock: JourneyFixtures.ManualClock())
        router.setRootName("Product list")

        router.rendererDidAppear()
        router.rendererDidAppear()

        let visit = try #require(router.screenVisit)
        #expect(visit.screen.title == "Product list")
        #expect(visit.transition == .appear)
        #expect(visit.callSite == nil)
        #expect(handler.journeyTexts.count == 1)
        #expect(Self.title(of: handler.journeyTexts.first) == "SHOWN ▸ Product list")
    }

    @Test
    func aPushOfSeveralRoutesVisitsOnlyTheTop() {
        let handler = RecordingLogHandler()
        let router = JourneyFixtures.stack(handler, clock: JourneyFixtures.ManualClock())

        router.push {
            ProductListRoute()
            ItemRoute(id: 1, title: nil)
            ItemRoute(id: 2, title: nil)
        }

        #expect(handler.journeyTexts.count == 1)
        #expect(router.screenVisit?.screen.title == "Product 2")
        #expect(router.screenVisit?.depth == 3)
    }

    @Test
    func goingBackVisitsTheScreenBelowWithTheTimeOnTheOneAbove() throws {
        let handler = RecordingLogHandler()
        let clock = JourneyFixtures.ManualClock()
        let router = JourneyFixtures.stack(handler, clock: clock)
        router.push(ProductListRoute())
        clock.advance(by: .seconds(2))
        router.push(ItemRoute(id: 3, title: nil))
        clock.advance(by: .milliseconds(5_700))

        router.rendererDidPop(toCount: 1)

        let visit = try #require(router.screenVisit)
        #expect(visit.screen.title == "Product list")
        #expect(visit.previous?.title == "Product 3")
        #expect(visit.timeOnPrevious == .milliseconds(5_700))
        #expect(visit.transition == .back)
        #expect(visit.origin == .user)
        #expect(visit.callSite == nil)
    }

    @Test
    func aChangeElsewhereVisitsNothing() {
        let handler = RecordingLogHandler()
        let tabs = JourneyFixtures.tabs(handler, clock: JourneyFixtures.ManualClock())
        tabs.router(for: .home).push(ProductListRoute())
        handler.removeAll()

        tabs.router(for: .shop).push(ItemRoute(id: 3, title: nil))

        #expect(handler.journeyTexts.isEmpty)
        #expect(tabs.screenVisit?.screen.title == "Product list")
    }

    @Test
    func aTabSwitchWritesTheTabThenTheScreen() throws {
        let handler = RecordingLogHandler()
        let tabs = JourneyFixtures.tabs(handler, clock: JourneyFixtures.ManualClock())
        tabs.router(for: .shop).setRootName("Product list")
        tabs.router(for: .home).push(ProductListRoute())
        handler.removeAll()

        tabs.select(.shop, trigger: "banner")

        let visit = try #require(tabs.screenVisit)
        #expect(visit.screen.title == "Product list")
        #expect(visit.source.title == "Shop")
        #expect(visit.transition == .tab)
        #expect(visit.trigger == "banner")
        let journey = visit.journey.map(\.title)
        let expectedJourney = [
            "Shop",
            "Product list",
        ]
        #expect(journey == expectedJourney)
        let texts = handler.journeyTexts
        #expect(texts.count == 1)
        let rows = Self.rows(of: texts.first)
        #expect(Self.title(of: texts.first) == "TAB ▸ Product list")
        #expect(rows.contains("coordinator  Shop (no coordinator named) · tab switch"))
        #expect(rows.contains("tab          Shop (from Home)"))
        #expect(rows.contains("trigger      banner"))
    }

    @Test
    func anUnnamedTabRootTakesTheTabsName() {
        let handler = RecordingLogHandler()
        let tabs = JourneyFixtures.tabs(handler, clock: JourneyFixtures.ManualClock())

        tabs.select(.profile)

        let expectedJourney = [
            "Profile",
        ]
        #expect(tabs.screenVisit?.screen.title == "Profile")
        #expect(tabs.screenVisit?.journey.map(\.title) == expectedJourney)
    }

    @Test
    func theSourceStaysWhileTheUserDrillsDown() throws {
        let handler = RecordingLogHandler()
        let tabs = JourneyFixtures.tabs(handler, clock: JourneyFixtures.ManualClock())
        let shop = tabs.router(for: .shop)
        tabs.select(.shop)

        shop.push(ProductListRoute())
        shop.push(ItemRoute(id: 3, title: nil))

        let visit = try #require(tabs.screenVisit)
        #expect(visit.source.title == "Shop")
        #expect(visit.previous?.title == "Product list")
        #expect(visit.depth == 2)
    }

    @Test
    func switchingTabRootsOnASharedStackVisitsTheNewTab() throws {
        let handler = RecordingLogHandler()
        let tabs = JourneyFixtures.tabs(handler, clock: JourneyFixtures.ManualClock(), stacks: .shared)
        tabs.router(for: .home).setRootName("Search")
        tabs.select(.shop)
        #expect(tabs.screenVisit?.screen.title == "Shop")

        tabs.select(.profile)

        let visit = try #require(tabs.screenVisit)
        #expect(visit.screen.title == "Profile")
        #expect(visit.journey.map(\.title) == ["Profile"])
    }

    @Test
    func aSheetOverSharedTabsStaysOneScreenWhenTheTabChanges() throws {
        let handler = RecordingLogHandler()
        let tabs = JourneyFixtures.tabs(handler, clock: JourneyFixtures.ManualClock(), stacks: .shared)
        tabs.present(JourneyFixtures.CheckoutRoute())
        let before = try #require(VisibleScreen(in: tabs)).key

        tabs.select(.shop)

        let after = try #require(VisibleScreen(in: tabs)).key
        #expect(after == before)
    }

    @Test
    func aNamedFlowOverSharedTabsKeepsItsName() throws {
        let handler = RecordingLogHandler()
        let tabs = JourneyFixtures.tabs(handler, clock: JourneyFixtures.ManualClock(), stacks: .shared)
        tabs.present(JourneyFixtures.CheckoutRoute())
        let presented = try #require(tabs.presented)
        presented.setRootName("Sign in")
        presented.setRootViewName("SignInView")

        #expect(VisibleScreen.rootName(of: presented) == "Sign in")
        #expect(VisibleScreen.level(of: presented).screens.first?.viewName == "SignInView")
    }

    @Test
    func theTabViewAtASharedStacksRootNamesNoScreen() throws {
        let handler = RecordingLogHandler()
        let tabs = JourneyFixtures.tabs(handler, clock: JourneyFixtures.ManualClock(), stacks: .shared)
        tabs.router(for: .home).setRootViewName("TabView")

        tabs.select(.shop)

        let visible = try #require(VisibleScreen(in: tabs))
        #expect(visible.screen.viewName == nil)
        #expect(visible.screen.title == "Shop")
    }

    @Test
    func aSharedStackIsNamedAfterTheSelectedTab() throws {
        let handler = RecordingLogHandler()
        let tabs = JourneyFixtures.tabs(handler, clock: JourneyFixtures.ManualClock(), stacks: .shared)
        tabs.select(.shop)

        tabs.router(for: .shop).push(ItemRoute(id: 3, title: nil))

        let visit = try #require(tabs.screenVisit)
        #expect(visit.source.title == "Shop")
        #expect(tabs.debugTree().contains("Shop"))
        #expect(!tabs.debugTree().contains("Stack"))
    }

    @Test
    func aScreenThatStartsAJourneyIsTheSourceOfWhatItOpens() throws {
        let handler = RecordingLogHandler()
        let tabs = JourneyFixtures.tabs(handler, clock: JourneyFixtures.ManualClock())
        let home = tabs.router(for: .home)
        home.push(JourneyFixtures.SearchRoute())
        #expect(tabs.screenVisit?.source.title == "Home")

        home.push(ItemRoute(id: 3, title: nil))
        home.push(ItemRoute(id: 4, title: nil))

        let visit = try #require(tabs.screenVisit)
        #expect(visit.source.title == "Search")
    }

    @Test
    func anUntrackedScreenIsLeftOut() throws {
        let handler = RecordingLogHandler()
        let router = JourneyFixtures.stack(handler, clock: JourneyFixtures.ManualClock())
        router.push(ProductListRoute())

        router.push(JourneyFixtures.LoadingRoute())
        router.pop()

        #expect(handler.journeyTexts.count == 1)
        let visit = try #require(router.screenVisit)
        #expect(visit.screen.title == "Product list")
    }

    @Test
    func aPresentedFlowStartsThenEnds() throws {
        let handler = RecordingLogHandler()
        let clock = JourneyFixtures.ManualClock()
        let router = JourneyFixtures.stack(handler, clock: clock)
        router.setRootName("Cart")
        router.rendererDidAppear()

        router.present(JourneyFixtures.CheckoutRoute(), style: .fullScreenCover, trigger: "checkout_button")
        let checkout = try #require(router.presented)
        clock.advance(by: .seconds(3))
        checkout.push(JourneyFixtures.CheckoutStep.payment)
        clock.advance(by: .seconds(9))
        router.dismiss()

        let texts = handler.journeyTexts
        let titles = texts.map(Self.title)
        let expectedTitles = [
            "SHOWN ▸ Cart",
            "FULL SCREEN ▸ Checkout · NEW COORDINATOR",
            "PUSH ▸ Checkout step: payment",
            "DISMISS ▸ Cart · FLOW ENDED",
        ]
        #expect(titles == expectedTitles)
        let started = Self.rows(of: texts[1])
        #expect(started.contains("coordinator  Checkout (no coordinator named) · presented by Main"))
        #expect(started.contains("trigger      checkout_button"))
        #expect(started.contains("step         1 of 3"))
        let ended = Self.rows(of: texts[3])
        #expect(ended.contains("previous     Checkout step: payment · 9.0 s there"))
        #expect(ended.contains("ended        checkout flow · finished after 12.0 s"))
        #expect(router.screenVisit?.transition == .dismiss)
    }

    @Test
    func aFlowTheUserDismissesIsCancelled() {
        let handler = RecordingLogHandler()
        let router = JourneyFixtures.stack(handler, clock: JourneyFixtures.ManualClock())
        router.present(JourneyFixtures.CheckoutRoute())

        router.rendererDidDismiss()

        let rows = Self.rows(of: handler.journeyTexts.last)
        #expect(rows.contains("ended        checkout flow · cancelled by the user after 0 ms"))
        #expect(rows.contains("by           user"))
    }

    @Test
    func aFlowWithStepsCountsThem() throws {
        let handler = RecordingLogHandler()
        let router = JourneyFixtures.stack(handler, clock: JourneyFixtures.ManualClock())
        router.present(JourneyFixtures.CheckoutRoute())
        let checkout = try #require(router.presented)
        #expect(router.screenVisit?.step == ScreenVisit.Step(number: 1, count: 3))

        checkout.push(JourneyFixtures.AddressFormRoute())
        #expect(router.screenVisit?.step == nil)
        checkout.pop()
        checkout.push(JourneyFixtures.CheckoutStep.payment)

        #expect(router.screenVisit?.step == ScreenVisit.Step(number: 2, count: 3))
        #expect(Self.rows(of: handler.journeyTexts.last).contains("step         2 of 3"))
    }

    @Test
    func aScreenViewedAgainSoonIsADuplicate() {
        let handler = RecordingLogHandler()
        let clock = JourneyFixtures.ManualClock()
        let router = JourneyFixtures.stack(handler, clock: clock)
        router.setDuplicatePushRule(.allow)
        router.push(ItemRoute(id: 3, title: nil))
        clock.advance(by: .milliseconds(180))

        router.push(ItemRoute(id: 3, title: nil))

        let duplicates = handler.messages.filter { message in
            message.text.contains("warning      shown again")
        }
        #expect(duplicates.count == 1)
        #expect(duplicates.first?.level == .notice)
        let rows = Self.rows(of: duplicates.first?.text)
        #expect(rows.contains("warning      shown again 180 ms after the last time"))
    }

    @Test
    func goingBackOrWaitingLongerIsNoDuplicate() {
        let handler = RecordingLogHandler()
        let clock = JourneyFixtures.ManualClock()
        let router = JourneyFixtures.stack(handler, clock: clock)
        router.push(ProductListRoute())
        router.push(ItemRoute(id: 3, title: nil))

        router.pop()
        clock.advance(by: .milliseconds(400))
        router.push(ItemRoute(id: 3, title: nil))

        #expect(!handler.texts.contains { $0.contains("shown again") })
    }

    @Test
    func theDuplicateWindowCanBeChanged() {
        let handler = RecordingLogHandler()
        let clock = JourneyFixtures.ManualClock()
        let logging = LogConfiguration().withDuplicateScreenWindow(.seconds(1))
        let router = JourneyFixtures.stack(handler, clock: clock, logging: logging)
        router.push(ItemRoute(id: 3, title: nil))
        router.pop()
        clock.advance(by: .milliseconds(800))

        router.push(ItemRoute(id: 3, title: nil))

        #expect(handler.texts.contains { $0.contains("shown again 800 ms after the last time") })
        #expect(LogConfiguration().duplicateScreenWindow == .milliseconds(300))
        #expect(LogConfiguration(duplicateScreenWindow: .seconds(-1)).duplicateScreenWindow == .zero)
    }

    @Test
    func theJourneyBoxIsInfoAndMechanicsAreDebug() {
        let handler = RecordingLogHandler()
        let router = JourneyFixtures.stack(handler, clock: JourneyFixtures.ManualClock())

        router.push(ProductListRoute())

        let levels = handler.messages.map(\.level)
        let expectedLevels: [LogLevel] = [.debug, .info]
        #expect(levels == expectedLevels)
        #expect(handler.messages.allSatisfy { $0.category == .navigation })
        #expect(handler.journeyBoxes.count == 1)
    }

    @Test
    func infoShowsOnlyTheJourney() {
        let handler = RecordingLogHandler()
        let logging = LogConfiguration(handler: handler, minimumLevel: .info)
        let router = StackRouter(configuration: NavigationConfiguration(logging: logging, registry: .permissive))

        router.push(ProductListRoute())
        router.push(ItemRoute(id: 3, title: nil))

        #expect(handler.routerTexts.isEmpty)
        #expect(handler.journeyTexts.count == 2)
    }

    @Test
    func theBoxNamesViewsAndCoordinatorsAndDrawsTheApp() throws {
        let handler = RecordingLogHandler()
        let tabs = JourneyFixtures.tabs(handler, clock: JourneyFixtures.ManualClock())
        tabs.setCoordinatorName("MainCoordinator")
        let shop = tabs.router(for: .shop)
        shop.setCoordinator(JourneyFixtures.ShopCoordinator())
        shop.setRootViewName("ProductListView")
        shop.registerViewName("ProductDetailView", for: ItemRoute.self)
        tabs.router(for: .home).setRootViewName("HomeView")
        tabs.select(.shop)
        handler.removeAll()

        shop.push(ItemRoute(id: 3, title: "Orbit Lamp"), trigger: "related_products")

        let box = try #require(handler.journeyBoxes.first)
        let expectedBox = [
            "┌─ 🧭 PUSH ▸ ProductDetailView ────────────────────────────────────────────────┐",
            "│ coordinator  ShopCoordinator · same coordinator (sub view)                   │",
            "│ tab          Shop                                                            │",
            "│ previous     ProductListView · 0 ms there                                    │",
            "│ by           app · JourneyTests.swift:NNN                                    │",
            "│ trigger      related_products                                                │",
            "│ route        Item (id: 3, …)                                                 │",
            "├─ app ────────────────────────────────────────────────────────────────────────┤",
            "│ MainCoordinator · tabs                                                       │",
            "│ ├── Home                    └ HomeView                                       │",
            "│ ├─▶ Shop · ShopCoordinator                                                   │",
            "│ │     ├ ProductListView                                                      │",
            "│ │     └ ProductDetailView (id: 3, …)   ◀ NEW                                 │",
            "│ └── Profile                 └ Profile                                        │",
            "└──────────────────────────────────────────────────────────────────────────────┘",
        ]
        let lines = box.replacingOccurrences(
            of: #"JourneyTests\.swift:\d{3}"#,
            with: "JourneyTests.swift:NNN",
            options: .regularExpression
        ).split(separator: "\n").map(String.init)
        #expect(lines == expectedBox)
    }

    @Test
    func theSampleSessionReadsAsOneBoxPerChange() {
        let handler = RecordingLogHandler()
        let clock = JourneyFixtures.ManualClock()
        let tabs = JourneyFixtures.tabs(handler, clock: clock)
        let shop = tabs.router(for: .shop)
        shop.setRootName("Product list")
        tabs.select(.shop)
        handler.removeAll()

        shop.push(ItemRoute(id: 3, title: "Orbit Lamp"))
        clock.advance(by: .milliseconds(5_700))
        shop.rendererDidPop(toCount: 0)
        shop.push(ItemRoute(id: 3, title: "Orbit Lamp"), trigger: "related_products")
        tabs.select(.home)

        let titles = handler.journeyTexts.map(Self.title)
        let expectedTitles = [
            "PUSH ▸ Product 3",
            "BACK ▸ Product list",
            "PUSH ▸ Product 3",
            "TAB ▸ Home",
        ]
        #expect(titles == expectedTitles)
        #expect(Self.rows(of: handler.journeyTexts[1]).contains("previous     Product 3 · 5.7 s there"))
    }

    @Test
    func withoutSymbolsTheLinesAreASCII() {
        let handler = RecordingLogHandler()
        let logging = LogConfiguration().withSymbols(false)
        let router = JourneyFixtures.stack(handler, clock: JourneyFixtures.ManualClock(), logging: logging)
        router.push(ProductListRoute())

        router.push(ItemRoute(id: 3, title: nil))

        let box = handler.journeyBoxes.last ?? ""
        #expect(box.hasPrefix("+- Waypoint PUSH > Product 3 --"))
        let drawn = ["│", "─", "┌", "└", "▶", "◀", "🧭"]
        #expect(!drawn.contains { box.contains($0) })
        #expect(box.contains("`- Product 3   <- NEW"))
    }

    @Test
    func structuredJourneyLinesHaveKeys() throws {
        let handler = RecordingLogHandler()
        let logging = LogConfiguration(format: .structured)
        let router = JourneyFixtures.stack(handler, clock: JourneyFixtures.ManualClock(), logging: logging)
        router.push(ProductListRoute())

        router.push(ItemRoute(id: 3, title: "Orbit Lamp"), trigger: "related")

        let last = try #require(handler.journeyTexts.last)
        let expectedStart = "screen_viewed screen=\"Product 3\" display=\"Orbit Lamp\" previous=\"Product list\" "
            + "source=\"Main\" how=push origin=app flow=main depth=2 trigger=related after_ms=0 at=JourneyTests.swift:"
        #expect(last.hasPrefix(expectedStart))
        #expect(handler.journeyBoxes.isEmpty)
    }

    @Test
    func viewNamesDropModifiersModulesAndGenerics() {
        #expect(ViewTypeName.simplified("Shop.ProductDetailView") == "ProductDetailView")
        #expect(ViewTypeName.simplified("ModifiedContent<ProductListView, _PaddingLayout>") == "ProductListView")
        let nested = "ModifiedContent<ModifiedContent<Shop.CartView, DestinationModifier<A, B>>, _FrameLayout>"
        #expect(ViewTypeName.simplified(nested) == "CartView")
        #expect(ViewTypeName.simplified("Optional<HomeView>") == "HomeView")
        #expect(ViewTypeName.simplified("ListView<Item>") == "ListView")
        #expect(ViewTypeName.simplified("EitherScreen<Shop.HomeView, Shop.SignInView>") == "HomeView")
        #expect(ViewTypeName.simplified("ControllerScreen<Scan.ScannerViewController>") == "ScannerViewController")
        let screen = "ModifiedContent<EitherScreen<Optional<CartView>, EmptyView>, _PaddingLayout>"
        #expect(ViewTypeName.simplified(screen) == "CartView")
        #expect(ViewTypeName.of(JourneyFixtures.ShopCoordinator.self) == "ShopCoordinator")
    }

    @Test
    func aPresentedFlowGrowsABranchUnderItsPresenter() throws {
        let handler = RecordingLogHandler()
        let router = JourneyFixtures.stack(handler, clock: JourneyFixtures.ManualClock())
        router.setCoordinatorName("CartCoordinator")
        router.setRootViewName("CartView")

        router.present(JourneyFixtures.CheckoutRoute(), style: .fullScreenCover)
        let checkout = try #require(router.presented)
        checkout.setCoordinatorName("CheckoutCoordinator")
        checkout.push(JourneyFixtures.CheckoutStep.payment)

        let rows = Self.rows(of: handler.journeyBoxes.last)
        let tree = Array(rows.drop { $0 != "CartCoordinator · stack" })
        let expectedTree = [
            "CartCoordinator · stack",
            "├ CartView",
            "└ ⧉ full screen · CheckoutCoordinator",
            "    ├ Checkout",
            "    └ Checkout step: payment   ◀ NEW",
        ]
        #expect(Array(tree.dropLast()) == expectedTree)
        #expect(rows.contains("coordinator  CheckoutCoordinator · same coordinator (sub view)"))
    }

    @Test
    func aPresentationWaitsForItsViewBeforeItsBox() throws {
        let handler = RecordingLogHandler()
        let router = JourneyFixtures.stack(handler, clock: JourneyFixtures.ManualClock())
        router.setCoordinatorName("CartCoordinator")
        router.setRootViewName("CartView")
        router.rendererDidAppear()

        router.present(JourneyFixtures.CheckoutRoute(), style: .fullScreenCover)
        #expect(handler.journeyBoxes.count == 1)
        let checkout = try #require(router.presented)
        checkout.setRootViewName("CheckoutAddressView")
        checkout.rendererDidAppear()
        checkout.push(JourneyFixtures.CheckoutStep.payment)

        let titles = handler.journeyBoxes.map(Self.title)
        let expectedTitles = [
            "SHOWN ▸ CartView",
            "FULL SCREEN ▸ CheckoutAddressView · NEW FLOW",
            "PUSH ▸ Checkout step: payment",
        ]
        #expect(titles == expectedTitles)
        #expect(Self.rows(of: handler.journeyBoxes.last).contains("previous     CheckoutAddressView · 0 ms there"))
    }

    @Test
    func aFlowWithItsOwnCoordinatorEndsThatCoordinator() throws {
        let handler = RecordingLogHandler()
        let router = JourneyFixtures.stack(handler, clock: JourneyFixtures.ManualClock())
        router.setCoordinatorName("CartCoordinator")
        router.present(JourneyFixtures.CheckoutRoute())
        let checkout = try #require(router.presented)
        checkout.setCoordinatorName("CheckoutCoordinator")
        checkout.push(JourneyFixtures.CheckoutStep.payment)

        router.dismiss()

        let box = handler.journeyBoxes.last
        #expect(Self.title(of: box) == "DISMISS ▸ Main · COORDINATOR ENDED")
        #expect(Self.rows(of: box).contains("ended        CheckoutCoordinator · finished after 0 ms"))
    }

    @Test
    func longMessagesSplitBetweenLinesUnderTheLimit() {
        let row = "│ " + String(repeating: "─", count: 40) + " │"
        let box = Array(repeating: row, count: 30).joined(separator: "\n")

        let pieces = LogChunks.split(box)

        #expect(pieces.count > 1)
        #expect(pieces.allSatisfy { $0.utf8.count <= LogChunks.maxBytes })
        #expect(pieces.joined(separator: "\n") == box)
        #expect(LogChunks.split("short") == ["short"])
        let long = String(repeating: "é", count: 20)
        #expect(LogChunks.split(long, maxBytes: 10).allSatisfy { $0.utf8.count <= 10 })
    }

    @Test
    func durationsReadAsPeopleSayThem() {
        #expect(JourneyLog.text(.milliseconds(180)) == "180 ms")
        #expect(JourneyLog.text(.milliseconds(5_740)) == "5.7 s")
        #expect(JourneyLog.text(.seconds(125)) == "2 min 5 s")
    }

    @Test
    func screenNamesComeFromTheRouteType() {
        let item = ScreenReference(route: AnyRoute(ItemRoute(id: 3, title: nil)), flow: FlowID("shop"))
        let list = ScreenReference(route: AnyRoute(ProductListRoute()), flow: FlowID("shop"))
        let step = ScreenReference(route: AnyRoute(JourneyFixtures.CheckoutStep.payment), flow: FlowID("checkout"))
        let product = ScreenReference(route: AnyRoute(ProductRoute(id: 7)), flow: FlowID("shop"))

        #expect(item.title == "Product 3")
        #expect(item.detail == "3")
        #expect(list.title == "Product list")
        #expect(step.title == "Checkout step: payment")
        #expect(product.title == "Product")
    }

    /// A box's title, such as `PUSH ▸ Product 3`, without the frame.
    static func title(of box: String?) -> String {
        guard let first = box?.split(separator: "\n").first else {
            return ""
        }
        let text = first.dropFirst(3).replacingOccurrences(of: "🧭 ", with: "")
        let end = text.range(of: " ─") ?? text.range(of: " -")
        return end.map { String(text[..<$0.lowerBound]) } ?? text
    }

    /// A box's lines without the frame and the trailing spaces.
    static func rows(of box: String?) -> [String] {
        (box ?? "").split(separator: "\n").map { line in
            var text = String(line.dropFirst(2).dropLast(2))
            while text.hasSuffix(" ") {
                text.removeLast()
            }
            return text
        }
    }
}
