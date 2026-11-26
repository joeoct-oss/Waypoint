//
//  ReadableLogTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import WaypointTestSupport

@testable import WaypointCore

/// The readable console format, one line per change with the stack after it, the stack and tree
/// views, and `debugTree()`.
@Suite("Readable log")
@MainActor
struct ReadableLogTests {
    /// A stack router that logs everything to a recording handler.
    private static func loggedStack(
        _ handler: RecordingLogHandler,
        _ configuration: LogConfiguration = LogConfiguration()
    ) -> StackRouter {
        let logging = configuration.withHandler(handler).withMinimumLevel(.debug)
        let router = StackRouter(configuration: NavigationConfiguration(logging: logging, registry: .permissive))
        return router
    }

    @Test("Readable logs with symbols are the default")
    func readableIsTheDefaultWithSymbols() {
        let configuration = LogConfiguration.default

        #expect(configuration.format == .readable)
        #expect(configuration.usesSymbols)
        #expect(configuration.treeLogging == .off)
    }

    @Test("Type names read as words")
    func typeNamesReadAsWords() {
        #expect(RouteDescriber.readableTypeName("ProductListRoute") == "Product list")
        #expect(RouteDescriber.readableTypeName("Shop.FAQRoute") == "FAQ")
        #expect(RouteDescriber.readableTypeName("URLPreviewRoute") == "URL preview")
        #expect(RouteDescriber.readableTypeName("Route") == "Route")
        #expect(RouteDescriber.readableTypeName("Checkout2Step") == "Checkout2 step")
    }

    @Test("Routes show public fields and fold private ones")
    func routesShowPublicFieldsAndFoldPrivateOnes() {
        let search = AnyRoute(RouteFixtures.SearchRoute(id: 3, query: "shoes"))

        #expect(AnyRoute(HomeRoute()).readableDescription(revealingPrivateValues: false) == "Home")
        #expect(AnyRoute(ProductRoute(id: 7)).readableDescription(revealingPrivateValues: false) == "Product (…)")
        #expect(search.readableDescription(revealingPrivateValues: false) == "Search (id: 3, …)")
        #expect(search.readableDescription(revealingPrivateValues: true) == "Search (id: 3, query: shoes)")
        #expect(AnyRoute(WizardStep.review).readableDescription(revealingPrivateValues: false) == "Wizard step: review")
    }

    @Test("Each change is one line with the stack after it")
    func eachChangeIsOneLineWithTheStackAfterIt() {
        let handler = RecordingLogHandler()
        let router = Self.loggedStack(handler)

        router.push(HomeRoute())
        router.push(ProductRoute(id: 7))
        router.pop()
        router.setPath {
            SettingsRoute()
        }
        router.present(SettingsRoute())
        router.dismiss()

        let expectedTexts = [
            "Waypoint  main       push     Home                     │ Main › Home",
            "Waypoint  main       push     Product (…)              │ Main › Home › Product (…)",
            "Waypoint  main       back     Product (…)              │ Main › Home",
            "Waypoint  main       set                               │ Main › Settings",
            "Waypoint  main       present  sheet settings           │ Settings",
            "Waypoint  main       dismiss  settings                 │ Main › Settings",
        ]
        #expect(handler.routerTexts == expectedTexts)
    }

    @Test("A deep stack is shortened to its ends in the log")
    func aDeepStackIsShortenedToItsEnds() {
        let handler = RecordingLogHandler()
        let router = Self.loggedStack(handler, LogConfiguration(revealsPrivateValues: true))

        for id in 2...6 {
            router.push(ProductRoute(id: id))
        }
        router.pop()

        let expectedLastTexts = [
            "Waypoint  main       push     Product (id: 5)          │ "
                + "Main › Product (id: 2) › Product (id: 3) › Product (id: 4) › Product (id: 5)",
            "Waypoint  main       push     Product (id: 6)          │ "
                + "Main › Product (id: 2) › … › Product (id: 5) › Product (id: 6) (5)",
            "Waypoint  main       back     Product (id: 6)          │ "
                + "Main › Product (id: 2) › Product (id: 3) › Product (id: 4) › Product (id: 5)",
        ]
        #expect(handler.routerTexts.suffix(3) == expectedLastTexts)
        #expect(!router.debugTree(revealingPrivateValues: true).contains("…"))
    }

    @Test("A stack with a root route names it")
    func aStackWithARootRouteNamesIt() {
        let handler = RecordingLogHandler()
        let logging = LogConfiguration(handler: handler, minimumLevel: .debug)
        let configuration = NavigationConfiguration(logging: logging, registry: .permissive)
        let router = StackRouter(root: HomeRoute(), configuration: configuration)

        router.push(SettingsRoute())

        #expect(handler.routerTexts == ["Waypoint  main       push     Settings                 │ Home › Settings"])
    }

    @Test("A change the user made says by user")
    func aUserChangeSaysByUser() {
        let handler = RecordingLogHandler()
        let router = Self.loggedStack(handler)
        router.push(HomeRoute())

        router.rendererDidPop(toCount: 0)

        #expect(handler.routerTexts.last == "Waypoint  main       back     Home, by user            │ Main")
    }

    @Test("Without symbols the separators are ASCII")
    func withoutSymbolsSeparatorsAreASCII() {
        let handler = RecordingLogHandler()
        let router = Self.loggedStack(handler, LogConfiguration(usesSymbols: false))

        router.push {
            HomeRoute()
            ProductRoute(id: 7)
        }
        router.popToRoot()

        let expectedTexts = [
            "Waypoint  main       push     Home > Product (…)       | Main > Home > Product (…)",
            "Waypoint  main       back     Home > Product (…)       | Main",
        ]
        #expect(handler.routerTexts == expectedTexts)
    }

    @Test("Tab changes name both tabs")
    func tabChangesNameBothTabs() {
        let handler = RecordingLogHandler()
        let logging = LogConfiguration(handler: handler, minimumLevel: .debug)
        let configuration = NavigationConfiguration(logging: logging, registry: .permissive)
        let tabs = TabRouter(tabs: MainTab.homeAndShop, selection: .home, configuration: configuration)

        tabs.select(.shop)

        let expectedTexts = ["Waypoint  tabs       tab      home → shop              │ Shop"]
        #expect(handler.routerTexts == expectedTexts)
    }

    @Test("A recovered issue is logged before its fallback")
    func recoveredIssueReadsBeforeItsFallback() {
        let handler = RecordingLogHandler()
        let router = Self.loggedStack(handler)
        router.push(HomeRoute())

        let line: UInt = #line + 1
        router.popTo(SettingsRoute(), else: .popToRoot)

        let expectedLastTexts = [
            "Waypoint  main       recover  can't go back to a screen that isn't in the stack\n"
                + "                              Settings is not in the path [Home]. "
                + "Check contains(_:) first, or handle the .failed outcome.\n"
                + "                              at ReadableLogTests.swift:\(line)",
            "Waypoint  main       back     Home, by fallback        │ Main",
        ]
        #expect(handler.routerTexts.suffix(2) == expectedLastTexts)
    }

    @Test("A failed issue is logged as a fault marked fail")
    func failedIssueIsMarkedAsFailed() throws {
        let handler = RecordingLogHandler()
        let router = Self.loggedStack(handler, LogConfiguration(usesSymbols: false))

        router.pop()

        let text = try #require(handler.routerTexts.first)
        #expect(text.hasPrefix("Waypoint  main       fail     can't go back: the first screen is already showing\n"))
        #expect(handler.routerMessages.first?.level == .fault)
    }

    @Test("Revealing private values shows them in the log but not in the issue")
    func revealingShowsValuesInIssueMessages() {
        let handler = RecordingLogHandler()
        let router = Self.loggedStack(handler, LogConfiguration(revealsPrivateValues: true))
        router.push(ProductRoute(id: 7))

        router.popTo(HomeRoute())

        #expect(handler.routerTexts.last?.contains("[Product (id: 7)]") == true)
        #expect(router.popTo(HomeRoute()).failure?.issue.message.contains("ProductRoute(id: <private>)") == true)
    }

    @Test("An issue's debug description reveals private values only when asked")
    func structuredIssueRevealsWhenAsked() throws {
        let router = StackRouter(configuration: .permissive)
        router.push(ProductRoute(id: 7))

        let issue = try #require(router.popTo(HomeRoute()).failure?.issue)

        #expect(issue.debugDescription(revealingPrivateValues: true).contains("[ProductRoute(id: 7)]"))
        #expect(issue.debugDescription(revealingPrivateValues: false).contains("[ProductRoute(id: <private>)]"))
    }

    @Test("Unchanged, queued and ignored calls say why")
    func unchangedQueuedAndIgnoredCallsSayWhy() throws {
        let handler = RecordingLogHandler()
        let router = Self.loggedStack(handler)
        router.present(SettingsRoute())
        let child = try #require(router.presented)
        router.dismiss()
        let once = Once()
        router.tree.onApplied { _ in
            guard once.claim() else {
                return
            }
            router.pop()
        }

        router.setPath { }
        child.push(HomeRoute())
        router.push(HomeRoute())

        let texts = handler.routerTexts.suffix(5).map { String($0.prefix(56)) }
        let expectedTexts = [
            "Waypoint  main       same     already there (ReadableLog",
            "Waypoint  settings   ignore   this flow is closed (Reada",
            "Waypoint  main       push     Home                     │",
            "Waypoint  main       queue    waits for the current chan",
            "Waypoint  main       back     Home                     │",
        ]
        #expect(texts == expectedTexts)
    }

    @Test("Every stack a change touched is logged after it")
    func changedStacksFollowEachChange() throws {
        let handler = RecordingLogHandler()
        let logging = LogConfiguration(handler: handler, minimumLevel: .debug, treeLogging: .changedStacks)
        let configuration = NavigationConfiguration(logging: logging, registry: .permissive)
        let tabs = TabRouter(tabs: MainTab.homeAndShop, selection: .home, configuration: configuration)

        tabs.router(for: .shop).push(ProductRoute(id: 7))
        tabs.select(.shop)
        tabs.present(SettingsRoute())

        let stackLines = handler.routerTexts.filter { $0.contains(" stack ") }
        let expectedStackLines = [
            "Waypoint  shop       stack    Shop › Product (…)",
            "Waypoint  shop       stack    Shop › Product (…)",
            "Waypoint  settings   stack    Settings",
        ]
        #expect(stackLines == expectedStackLines)
    }

    @Test("The whole tree is logged after each change when asked")
    func wholeTreeIsLoggedAfterEachChange() {
        let handler = RecordingLogHandler()
        let router = Self.loggedStack(handler, LogConfiguration(treeLogging: .wholeTree))

        router.push(HomeRoute())

        let expectedTexts = [
            "Waypoint  main       push     Home                     │ Main › Home",
            "tree after the change:\nmain       Main › Home",
        ]
        #expect(handler.routerTexts == expectedTexts)
    }

    @Test("debugTree draws every flow from any router in the tree")
    func debugTreeDrawsEveryFlow() throws {
        let tabs = TabRouter(selection: MainTab.shop, configuration: .permissive)
        tabs.router(for: .shop).push(ProductRoute(id: 7))
        tabs.router(for: .shop).present(SettingsRoute())
        try #require(tabs.router(for: .shop).presented).push(HomeRoute())

        let expected = [
            "\(tabs.flowID.name.padding(toLength: 18, withPad: " ", startingAt: 0)) home · [shop] · profile",
            "├ home             Home",
            "├ shop             Shop › Product (…)",
            "│ └ sheet settings Settings › Home",
            "└ profile          Profile",
        ]
        #expect(tabs.debugTree() == expected.joined(separator: "\n"))
        #expect(tabs.router(for: .home).debugTree() == tabs.debugTree())
    }

    @Test("debugTree reveals private values only when asked")
    func debugTreeRevealsWhenAsked() {
        let router = StackRouter(configuration: .permissive)
        router.push(ProductRoute(id: 7))

        #expect(router.debugTree() == "main       Main › Product (…)")
        #expect(router.debugTree(revealingPrivateValues: true) == "main       Main › Product (id: 7)")
    }

    @Test("A structured presentation line names the presenter")
    func structuredPresentationNamesThePresenter() {
        let handler = RecordingLogHandler()
        let router = Self.loggedStack(handler, LogConfiguration(format: .structured))

        router.present(SettingsRoute())
        router.dismiss()

        let expectedTexts = [
            "presented sheet SettingsRoute flow=settings presenter=main",
            "dismissed flow=settings presenter=main",
        ]
        #expect(handler.routerTexts == expectedTexts)
    }

    @Test("A structured stack line lists the flow and path")
    func structuredStackLine() {
        let handler = RecordingLogHandler()
        let router = Self.loggedStack(handler, LogConfiguration(format: .structured, treeLogging: .changedStacks))

        router.push(HomeRoute())

        #expect(handler.routerTexts.last == "stack flow=main path=[HomeRoute]")
    }
}
