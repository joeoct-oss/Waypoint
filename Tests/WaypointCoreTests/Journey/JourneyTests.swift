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

/// The journey (#216): the screen on display after each change across tabs, stacks and
/// presentations, its visit with the previous screen and the source, and the journey lines.
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
        let expectedTexts = ["🧭 screen_viewed  Product list"]
        #expect(handler.journeyTexts == expectedTexts)
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
        #expect(texts.count == 2)
        #expect(texts.first == "🧭 tab_selected   Shop                       ◀ Home · trigger banner")
    }

    @Test
    func anUnnamedTabRootTakesTheTabsName() {
        let handler = RecordingLogHandler()
        let tabs = JourneyFixtures.tabs(handler, clock: JourneyFixtures.ManualClock())

        tabs.select(.profile)

        #expect(tabs.screenVisit?.screen.title == "Profile")
        #expect(tabs.screenVisit?.journey.map(\.title) == ["Profile"])
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
        #expect(texts.count == 6)
        #expect(texts[1].hasPrefix("🧭 flow_started   Checkout                   from Cart · full screen · by app ("))
        #expect(texts[1].hasSuffix(") · trigger checkout_button"))
        #expect(texts[2].hasPrefix("🧭 screen_viewed  Checkout                   ◀ Cart after 0 ms · full screen by app"))
        #expect(texts[4].hasPrefix("🧭 flow_finished  Checkout                   after 12.0 s · by app ("))
        #expect(texts[5].hasPrefix("🧭 screen_viewed  Cart                       ◀ Checkout step: payment after 9.0 s"))
        #expect(router.screenVisit?.transition == .dismiss)
    }

    @Test
    func aFlowTheUserDismissesIsCancelled() {
        let handler = RecordingLogHandler()
        let router = JourneyFixtures.stack(handler, clock: JourneyFixtures.ManualClock())
        router.present(JourneyFixtures.CheckoutRoute())

        router.rendererDidDismiss()

        let ended = handler.journeyTexts.filter { $0.contains("flow_") }
        #expect(ended.last == "🧭 flow_cancelled Checkout                   after 0 ms · by user")
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
        #expect(handler.journeyTexts.last?.contains("step 2 of 3") == true)
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
            message.text.hasPrefix("⚠️")
        }
        #expect(duplicates.count == 1)
        #expect(duplicates.first?.level == .notice)
        #expect(duplicates.first?.text.hasPrefix("⚠️ duplicate      Product 3 viewed twice, 180 ms apart (JourneyTests.swift:") == true)
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

        #expect(!handler.texts.contains { $0.hasPrefix("⚠️") })
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

        #expect(handler.texts.contains { $0.hasPrefix("⚠️ duplicate      Product 3 viewed twice, 800 ms apart") })
        #expect(LogConfiguration().duplicateScreenWindow == .milliseconds(300))
        #expect(LogConfiguration(duplicateScreenWindow: .seconds(-1)).duplicateScreenWindow == .zero)
    }

    @Test
    func journeyLinesAreInfoAndMechanicsAreDebug() {
        let handler = RecordingLogHandler()
        let router = JourneyFixtures.stack(handler, clock: JourneyFixtures.ManualClock())

        router.push(ProductListRoute())

        let levels = handler.messages.map(\.level)
        let expectedLevels: [LogLevel] = [.debug, .info, .debug]
        #expect(levels == expectedLevels)
        #expect(handler.messages.allSatisfy { $0.category == .navigation })
        #expect(handler.journeyTexts.count == 1)
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
    func theDebugBoxHasEveryField() throws {
        let handler = RecordingLogHandler()
        let tabs = JourneyFixtures.tabs(handler, clock: JourneyFixtures.ManualClock())
        let shop = tabs.router(for: .shop)
        shop.setRootName("Product list")
        tabs.select(.shop)
        handler.removeAll()

        shop.push(ItemRoute(id: 3, title: "Orbit Lamp"), trigger: "related_products")

        let box = try #require(handler.journeyBoxes.first)
        let rows = box.split(separator: "\n").map(String.init)
        #expect(rows.first?.hasPrefix("┌─ 🧭 screen_viewed · Product 3 ──") == true)
        #expect(rows.contains("│  screen    : Product 3 \"Orbit Lamp\""))
        #expect(rows.contains("│  route     : Item (id: 3, …)"))
        #expect(rows.contains("│  previous  : Product list, after 0 ms"))
        #expect(rows.contains("│  source    : Shop"))
        #expect(rows.contains("│  journey   : Shop › Product list › Product 3 (depth 2)"))
        #expect(rows.contains("│  trigger   : related_products"))
        #expect(rows.contains("│  flow      : shop"))
        #expect(rows.contains { $0.hasPrefix("│  how       : push, by app at JourneyTests.swift:") })
        #expect(rows.last?.hasPrefix("└──") == true)
    }

    @Test
    func theSampleSessionReadsAsJourneyLines() {
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

        let texts = handler.journeyTexts.map(Self.withoutCallSite)
        let expectedTexts = [
            "🧭 screen_viewed  Product 3 \"Orbit Lamp\"     ◀ Product list after 0 ms · push by app",
            "🧭 screen_viewed  Product list               ◀ Product 3 after 5.7 s · back by user",
            "🧭 screen_viewed  Product 3 \"Orbit Lamp\"     ◀ Product list after 0 ms · push by app · trigger related_products",
            "🧭 tab_selected   Home                       ◀ Shop",
            "🧭 screen_viewed  Home                       ◀ Product 3 after 0 ms · tab by app",
        ]
        #expect(texts == expectedTexts)
    }

    @Test
    func withoutSymbolsTheLinesAreASCII() {
        let handler = RecordingLogHandler()
        let logging = LogConfiguration().withSymbols(false)
        let router = JourneyFixtures.stack(handler, clock: JourneyFixtures.ManualClock(), logging: logging)
        router.push(ProductListRoute())

        router.push(ItemRoute(id: 3, title: nil))

        let last = handler.journeyTexts.last.map(Self.withoutCallSite)
        #expect(last == "Waypoint screen_viewed  Product 3                  <- Product list after 0 ms | push by app")
        #expect(handler.journeyBoxes.last?.hasPrefix("+- Waypoint screen_viewed | Product 3 --") == true)
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

    /// A journey line without its call site, which moves when this file changes.
    private static func withoutCallSite(_ text: String) -> String {
        text.replacingOccurrences(of: #" \(JourneyTests\.swift:\d+\)"#, with: "", options: .regularExpression)
    }
}
