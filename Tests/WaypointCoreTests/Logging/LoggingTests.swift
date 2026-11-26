//
//  LoggingTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import Understudy
import WaypointTestSupport

@testable import WaypointCore

/// The logging seam: levels, categories, privacy, issues and intervals, checked in
/// the structured format, whose lines are pinned. `ReadableLogTests` pins the readable format.
@Suite("Logging")
@MainActor
struct LoggingTests {
    @Test("The default log configuration is quiet and logs nothing")
    func defaultConfigurationIsQuietAndCheap() {
        let configuration = LogConfiguration.default

        #expect(configuration.minimumLevel == .notice)
        #expect(configuration.categories == nil)
        #expect(!configuration.revealsPrivateValues)
        #expect(!configuration.isEnabled(level: .fault, category: .issues))
        #expect(StackRouter(configuration: .permissive).configuration.logging.handler is DisabledLogHandler)
    }

    @Test("A disabled handler never builds a message")
    func disabledHandlerNeverBuildsMessage() {
        let handler = RecordingLogHandler(accepts: false)
        let logging = LogConfiguration(handler: handler, minimumLevel: .debug, format: .structured)
        let router = StackRouter(configuration: NavigationConfiguration(logging: logging, registry: .permissive))
        let built = Spy<String, Void>()

        router.tree.log(.fault, .issues, file: #fileID, line: #line) { _ in
            built("built")
            return "never"
        }
        router.push(HomeRoute())

        #expect(built.callCount == 0)
        #expect(handler.checks > 0)
        #expect(handler.routerMessages.isEmpty)
        #expect(handler.intervals.isEmpty)
    }

    @Test("A level below the minimum is skipped")
    func levelBelowMinimumIsSkippedBeforeAskingTheHandler() {
        let handler = RecordingLogHandler()
        let logging = LogConfiguration(handler: handler, minimumLevel: .notice, format: .structured)
        let router = StackRouter(configuration: NavigationConfiguration(logging: logging, registry: .permissive))

        router.push(HomeRoute())
        router.setPath {
            HomeRoute()
        }

        #expect(handler.routerMessages.isEmpty)
        #expect(handler.checks == 2)
    }

    @Test("A disabled category is skipped")
    func disabledCategoryIsSkipped() {
        let handler = RecordingLogHandler()
        let presentationOnly: Set<LogCategory> = [.presentation]
        let logging = LogConfiguration(
            handler: handler,
            minimumLevel: .debug,
            categories: presentationOnly,
            format: .structured
        )
        let router = StackRouter(configuration: NavigationConfiguration(logging: logging, registry: .permissive))

        router.push(HomeRoute())
        router.present(SettingsRoute())

        let expectedCategories: [LogCategory] = [.presentation]
        #expect(handler.routerMessages.map(\.category) == expectedCategories)
        #expect(handler.routerTexts.first?.hasPrefix("presented ") == true)
    }

    @Test("Changes are logged at debug in their category")
    func changesAreLoggedAtDebugInTheirCategory() {
        let handler = RecordingLogHandler()
        let logging = LogConfiguration(handler: handler, minimumLevel: .debug, format: .structured)
        let configuration = NavigationConfiguration(logging: logging, registry: .permissive)
        let tabs = TabRouter(tabs: MainTab.homeAndShop, selection: .home, configuration: configuration)

        tabs.select(.shop)
        tabs.router(for: .shop).push(HomeRoute())

        let expectedLevels: [LogLevel] = [.debug, .debug]
        #expect(handler.routerMessages.map(\.level) == expectedLevels)
        let expectedCategories: [LogCategory] = [.tabs, .navigation]
        #expect(handler.routerMessages.map(\.category) == expectedCategories)
        #expect(handler.routerTexts.last?.hasSuffix(" flow=shop") == true)
    }

    @Test("A child router shares the log configuration")
    func childRouterSharesTheConfiguration() throws {
        let handler = RecordingLogHandler()
        let logging = LogConfiguration(handler: handler, minimumLevel: .debug, format: .structured)
        let router = StackRouter(configuration: NavigationConfiguration(logging: logging, registry: .permissive))
        router.present(SettingsRoute())
        let child = try #require(router.presented)
        handler.removeAll()

        child.push(HomeRoute())

        #expect(child.configuration.logging.minimumLevel == .debug)
        let expectedTexts = ["pushed [HomeRoute] flow=\(child.flowID)"]
        #expect(handler.routerTexts == expectedTexts)
    }

    @Test("Private values are redacted by default")
    func privateValuesAreRedactedByDefault() {
        let handler = RecordingLogHandler()
        let logging = LogConfiguration(handler: handler, minimumLevel: .debug, format: .structured)
        let router = StackRouter(configuration: NavigationConfiguration(logging: logging, registry: .permissive))

        router.push(ProductRoute(id: 7))

        let expectedTexts = ["pushed [ProductRoute(id: <private>)] flow=main"]
        #expect(handler.routerTexts == expectedTexts)
    }

    @Test("Public log fields are shown and private ones hidden")
    func publicLogFieldsAreShown() {
        let handler = RecordingLogHandler()
        let logging = LogConfiguration(handler: handler, minimumLevel: .debug, format: .structured)
        let router = StackRouter(configuration: NavigationConfiguration(logging: logging, registry: .permissive))

        router.push(RouteFixtures.SearchRoute(id: 3, query: "shoes"))

        let text = handler.routerTexts.first ?? ""
        #expect(text.contains("id: 3"))
        #expect(!text.contains("shoes"))
    }

    @Test("Revealing private values shows everything")
    func revealsPrivateValuesShowsEverything() {
        let handler = RecordingLogHandler()
        let logging = LogConfiguration(
            handler: handler,
            minimumLevel: .debug,
            revealsPrivateValues: true,
            format: .structured
        )
        let router = StackRouter(configuration: NavigationConfiguration(logging: logging, registry: .permissive))

        router.push(ProductRoute(id: 7))

        let expectedTexts = ["pushed [ProductRoute(id: 7)] flow=main"]
        #expect(handler.routerTexts == expectedTexts)
    }

    @Test("Fallback changes say where they came from")
    func fallbackChangesSayWhereTheyCameFrom() {
        let handler = RecordingLogHandler()
        let navigationOnly: Set<LogCategory> = [.navigation]
        let logging = LogConfiguration(
            handler: handler,
            minimumLevel: .debug,
            categories: navigationOnly,
            format: .structured
        )
        let router = StackRouter(configuration: NavigationConfiguration(logging: logging, registry: .permissive))
        router.push(HomeRoute())
        handler.removeAll()

        router.popTo(SettingsRoute(), else: .popToRoot)

        let expectedTexts = ["popped [HomeRoute] flow=main origin=fallback"]
        #expect(handler.routerTexts == expectedTexts)
    }

    @Test("Every issue is logged with its level and call site")
    func everyIssueIsLoggedWithItsCallSite() throws {
        let handler = RecordingLogHandler()
        let issuesOnly: Set<LogCategory> = [.issues]
        let logging = LogConfiguration(handler: handler, categories: issuesOnly, format: .structured)
        let router = StackRouter(configuration: NavigationConfiguration(logging: logging, registry: .permissive))
        router.push(HomeRoute())
        handler.removeAll()

        let recoveredLine: UInt = #line + 1
        router.pop(count: 2)
        let failedLine: UInt = #line + 1
        router.popTo(SettingsRoute())

        let messages = handler.routerMessages
        try #require(messages.count == 2)
        let expectedLevels: [LogLevel] = [.error, .fault]
        #expect(messages.map(\.level) == expectedLevels)
        let expectedLines = [recoveredLine, failedLine]
        #expect(messages.map(\.line) == expectedLines)
        #expect("\(messages[1].file)" == #fileID)
        #expect(messages[0].text.hasPrefix("notEnoughRoutes flow=main at=LoggingTests.swift:"))
        #expect(messages[1].text.contains("\n  "))
    }

    @Test("Unchanged, stale and reentrant calls are logged with their call site")
    func unchangedQueuedAndIgnoredCallsLogAtDebug() throws {
        let handler = RecordingLogHandler()
        let navigationOnly: Set<LogCategory> = [.navigation]
        let logging = LogConfiguration(
            handler: handler,
            minimumLevel: .debug,
            categories: navigationOnly,
            format: .structured
        )
        let router = StackRouter(configuration: NavigationConfiguration(logging: logging, registry: .permissive))
        router.present(SettingsRoute())
        let child = try #require(router.presented)
        router.dismiss()
        router.push(HomeRoute())
        handler.removeAll()
        let once = Once()
        router.tree.onApplied { _ in
            guard once.claim() else {
                return
            }
            router.pop()
        }

        router.setPath {
            HomeRoute()
        }
        child.push(HomeRoute())
        router.push(ProductRoute(id: 1))

        let texts = handler.routerTexts
        #expect(texts.count == 5)
        #expect(texts[0].hasPrefix("alreadyThere flow=main at=LoggingTests.swift:"))
        #expect(texts[1].hasPrefix("staleNavigator flow=settings at=LoggingTests.swift:"))
        #expect(texts[2].hasPrefix("pushed "))
        #expect(texts[3].hasPrefix("reentrantChange flow=main at=LoggingTests.swift:"))
        #expect(texts[4].hasPrefix("popped "))
    }

    @Test("Registry problems are logged as errors")
    func registryProblemsAreLoggedAsErrors() {
        let handler = RecordingLogHandler()
        let logging = LogConfiguration(handler: handler, format: .structured)
        let router = StackRouter(configuration: NavigationConfiguration(logging: logging, registry: .permissive))

        router.register(RouteFixtures.EmptyFormerKeyRoute.self)

        let expectedLevels: [LogLevel] = [.error]
        #expect(handler.routerMessages.map(\.level) == expectedLevels)
        let expectedCategories: [LogCategory] = [.issues]
        #expect(handler.routerMessages.map(\.category) == expectedCategories)
    }

    @Test("Each transaction is one interval, also when it fails")
    func eachTransactionIsOneIntervalAlsoWhenItFails() {
        let handler = RecordingLogHandler()
        let logging = LogConfiguration(handler: handler, format: .structured)
        let router = StackRouter(configuration: NavigationConfiguration(logging: logging, registry: .permissive))

        router.transaction {
            $0.push(HomeRoute())
            $0.push(ProductRoute(id: 1))
        }
        router.popTo(SettingsRoute())

        let first = LogInterval(name: "transaction", category: .navigation, id: 1)
        let second = LogInterval(name: "transaction", category: .navigation, id: 2)
        let expectedIntervals: [RecordingLogHandler.IntervalEvent] = [
            .began(first),
            .ended(first),
            .began(second),
            .ended(second),
        ]
        #expect(handler.intervals == expectedIntervals)
    }

    @Test("Intervals are skipped when their category is off")
    func intervalsAreSkippedWhenTheCategoryIsOff() {
        let handler = RecordingLogHandler()
        let issuesOnly: Set<LogCategory> = [.issues]
        let logging = LogConfiguration(handler: handler, categories: issuesOnly, format: .structured)
        let router = StackRouter(configuration: NavigationConfiguration(logging: logging, registry: .permissive))
        router.push(HomeRoute())
        handler.removeAll()

        router.push(HomeRoute())

        #expect(handler.intervals.isEmpty)
    }

    @Test("The recording handler keeps every message from many threads")
    func recordingHandlerKeepsOrderAcrossThreads() async {
        let handler = RecordingLogHandler()

        await withTaskGroup(of: Void.self) { group in
            for index in 0..<50 {
                group.addTask {
                    let message = LogMessage(
                        level: .info,
                        category: .navigation,
                        text: "\(index)",
                        file: #fileID,
                        line: #line
                    )
                    handler.log(message)
                }
            }
        }

        #expect(Set(handler.routerTexts).count == 50)
    }
}
