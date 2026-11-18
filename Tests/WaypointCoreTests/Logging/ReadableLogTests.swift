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

/// The readable console format, the stack and tree views, and `debugTree()` (#117).
@Suite("Readable log")
@MainActor
struct ReadableLogTests {
    /// A stack router that logs everything to a recording handler.
    private static func loggedStack(
        _ handler: RecordingLogHandler,
        _ configuration: LogConfiguration = LogConfiguration()
    ) -> StackRouter {
        let logging = configuration.withHandler(handler).withMinimumLevel(.debug)
        let router = StackRouter(configuration: NavigationConfiguration(logging: logging))
        return router
    }

    @Test
    func readableIsTheDefaultWithSymbols() {
        let configuration = LogConfiguration.default

        #expect(configuration.format == .readable)
        #expect(configuration.usesSymbols)
        #expect(configuration.treeLogging == .off)
    }

    @Test
    func typeNamesReadAsWords() {
        #expect(RouteDescriber.readableTypeName("ProductListRoute") == "Product list")
        #expect(RouteDescriber.readableTypeName("Shop.FAQRoute") == "FAQ")
        #expect(RouteDescriber.readableTypeName("URLPreviewRoute") == "URL preview")
        #expect(RouteDescriber.readableTypeName("Route") == "Route")
        #expect(RouteDescriber.readableTypeName("Checkout2Step") == "Checkout2 step")
    }

    @Test
    func routesShowPublicFieldsAndFoldPrivateOnes() {
        let search = AnyRoute(RouteFixtures.SearchRoute(id: 3, query: "shoes"))

        #expect(AnyRoute(HomeRoute()).readableDescription(revealingPrivateValues: false) == "Home")
        #expect(AnyRoute(ProductRoute(id: 7)).readableDescription(revealingPrivateValues: false) == "Product (…)")
        #expect(search.readableDescription(revealingPrivateValues: false) == "Search (id: 3, …)")
        #expect(search.readableDescription(revealingPrivateValues: true) == "Search (id: 3, query: shoes)")
        #expect(AnyRoute(WizardStep.review).readableDescription(revealingPrivateValues: false) == "Wizard step: review")
    }

    @Test
    func changesReadAsSentences() {
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
            "main       ▸ push Home",
            "main       ▸ push Product (…)",
            "main       ◂ back to Home (closed Product (…))",
            "main       ↻ set the stack to Settings",
            "main       ↑ present sheet settings: Settings",
            "main       ↓ dismiss settings",
        ]
        #expect(handler.texts == expectedTexts)
    }

    @Test
    func wordsOnlyDropsTheSymbols() {
        let handler = RecordingLogHandler()
        let router = Self.loggedStack(handler, LogConfiguration(usesSymbols: false))

        router.push {
            HomeRoute()
            ProductRoute(id: 7)
        }
        router.popToRoot()

        let expectedTexts = [
            "main       push Home > Product (…)",
            "main       back to the first screen (closed Home > Product (…))",
        ]
        #expect(handler.texts == expectedTexts)
    }

    @Test
    func tabChangesNameBothTabs() {
        let handler = RecordingLogHandler()
        let logging = LogConfiguration(handler: handler, minimumLevel: .info)
        let configuration = NavigationConfiguration(logging: logging)
        let tabs = TabRouter(tabs: MainTab.homeAndShop, selection: .home, configuration: configuration)

        tabs.select(.shop)

        let expectedTexts = ["tabs       ⇥ tab home → shop"]
        #expect(handler.texts == expectedTexts)
    }

    @Test
    func recoveredIssueReadsBeforeItsFallback() {
        let handler = RecordingLogHandler()
        let router = Self.loggedStack(handler)
        router.push(HomeRoute())

        let line: UInt = #line + 1
        router.popTo(SettingsRoute(), else: .popToRoot)

        let expectedLastTexts = [
            "main       ⚠︎ recovered: can't go back to a screen that isn't in the stack\n"
                + "             Settings is not in the path [Home]. Check contains(_:) first, or handle the .failed outcome.\n"
                + "             at ReadableLogTests.swift:\(line)",
            "main       ◂ back to the first screen (closed Home) · by fallback",
        ]
        #expect(handler.texts.suffix(2) == expectedLastTexts)
    }

    @Test
    func failedIssueIsMarkedAsFailed() throws {
        let handler = RecordingLogHandler()
        let router = Self.loggedStack(handler, LogConfiguration(usesSymbols: false))

        router.pop()

        let text = try #require(handler.texts.first)
        #expect(text.hasPrefix("main       failed: can't go back: the first screen is already showing\n"))
        #expect(handler.messages.first?.level == .fault)
    }

    @Test
    func revealingShowsValuesInIssueMessages() {
        let handler = RecordingLogHandler()
        let router = Self.loggedStack(handler, LogConfiguration(revealsPrivateValues: true))
        router.push(ProductRoute(id: 7))

        router.popTo(HomeRoute())

        #expect(handler.texts.last?.contains("[Product (id: 7)]") == true)
        #expect(router.popTo(HomeRoute()).failure?.issue.message.contains("ProductRoute(id: <private>)") == true)
    }

    @Test
    func structuredIssueRevealsWhenAsked() throws {
        let router = StackRouter()
        router.push(ProductRoute(id: 7))

        let issue = try #require(router.popTo(HomeRoute()).failure?.issue)

        #expect(issue.debugDescription(revealingPrivateValues: true).contains("[ProductRoute(id: 7)]"))
        #expect(issue.debugDescription(revealingPrivateValues: false).contains("[ProductRoute(id: <private>)]"))
    }

    @Test
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

        let texts = handler.texts.suffix(5).map { String($0.prefix(40)) }
        let expectedTexts = [
            "main       = already there (ReadableLogT",
            "settings   ∅ ignored: this flow is close",
            "main       ▸ push Home",
            "main       … queued until the current ch",
            "main       ◂ back to the first screen (c",
        ]
        #expect(texts == expectedTexts)
    }

    @Test
    func changedStacksFollowEachChange() throws {
        let handler = RecordingLogHandler()
        let logging = LogConfiguration(handler: handler, minimumLevel: .info, treeLogging: .changedStacks)
        let configuration = NavigationConfiguration(logging: logging)
        let tabs = TabRouter(tabs: MainTab.homeAndShop, selection: .home, configuration: configuration)

        tabs.router(for: .shop).push(ProductRoute(id: 7))
        tabs.select(.shop)
        tabs.present(SettingsRoute())

        let stackLines = handler.texts.filter { $0.contains(" ≡ ") }
        let expectedStackLines = [
            "shop       ≡ Product (…)",
            "shop       ≡ Product (…)",
            "settings   ≡ Settings",
        ]
        #expect(stackLines == expectedStackLines)
    }

    @Test
    func wholeTreeIsLoggedAfterEachChange() {
        let handler = RecordingLogHandler()
        let router = Self.loggedStack(handler, LogConfiguration(treeLogging: .wholeTree))

        router.push(HomeRoute())

        let expectedTexts = [
            "main       ▸ push Home",
            "tree after the change:\nmain       Home",
        ]
        #expect(handler.texts == expectedTexts)
    }

    @Test
    func debugTreeDrawsEveryFlow() throws {
        let tabs = TabRouter(selection: MainTab.shop)
        tabs.router(for: .shop).push(ProductRoute(id: 7))
        tabs.router(for: .shop).present(SettingsRoute())
        try #require(tabs.router(for: .shop).presented).push(HomeRoute())

        let expected = [
            "\(tabs.flowID.name.padding(toLength: 18, withPad: " ", startingAt: 0)) home · [shop] · profile",
            "├ home             first screen",
            "├ shop             Product (…)",
            "│ └ sheet settings Settings › Home",
            "└ profile          first screen",
        ]
        #expect(tabs.debugTree() == expected.joined(separator: "\n"))
        #expect(tabs.router(for: .home).debugTree() == tabs.debugTree())
    }

    @Test
    func debugTreeRevealsWhenAsked() {
        let router = StackRouter()
        router.push(ProductRoute(id: 7))

        #expect(router.debugTree() == "main       Product (…)")
        #expect(router.debugTree(revealingPrivateValues: true) == "main       Product (id: 7)")
    }

    @Test
    func structuredPresentationNamesThePresenter() {
        let handler = RecordingLogHandler()
        let router = Self.loggedStack(handler, LogConfiguration(format: .structured))

        router.present(SettingsRoute())
        router.dismiss()

        let expectedTexts = [
            "presented sheet SettingsRoute flow=settings presenter=main",
            "dismissed flow=settings presenter=main",
        ]
        #expect(handler.texts == expectedTexts)
    }

    @Test
    func structuredStackLine() {
        let handler = RecordingLogHandler()
        let router = Self.loggedStack(handler, LogConfiguration(format: .structured, treeLogging: .changedStacks))

        router.push(HomeRoute())

        #expect(handler.texts.last == "stack flow=main path=[HomeRoute]")
    }
}
