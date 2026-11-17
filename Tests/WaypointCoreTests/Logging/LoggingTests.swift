//
//  LoggingTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import WaypointTestSupport

@testable import WaypointCore

/// The logging seam: levels, categories, privacy, issues and intervals (#77), checked in the
/// structured format, whose lines are pinned. `ReadableLogTests` pins the readable format.
@Suite("Logging")
@MainActor
struct LoggingTests {
    @Test
    func defaultConfigurationIsQuietAndCheap() {
        let configuration = LogConfiguration.default

        #expect(configuration.minimumLevel == .notice)
        #expect(configuration.categories == nil)
        #expect(!configuration.revealsPrivateValues)
        #expect(!configuration.isEnabled(level: .fault, category: .issues))
        #expect(StackRouter().logging.handler is DisabledLogHandler)
    }

    @Test
    func disabledHandlerNeverBuildsMessage() {
        let handler = RecordingLogHandler(accepts: false)
        let router = StackRouter()
        router.setLogging(LogConfiguration(handler: handler, minimumLevel: .debug, format: .structured))
        let built = Recorder<String>()

        router.tree.log(.fault, .issues, file: #fileID, line: #line) { _ in
            built.record("built")
            return "never"
        }
        router.push(HomeRoute())

        #expect(built.count == 0)
        #expect(handler.checks > 0)
        #expect(handler.messages.isEmpty)
        #expect(handler.intervals.isEmpty)
    }

    @Test
    func levelBelowMinimumIsSkippedBeforeAskingTheHandler() {
        let handler = RecordingLogHandler()
        let router = StackRouter()
        router.setLogging(LogConfiguration(handler: handler, minimumLevel: .notice, format: .structured))

        router.push(HomeRoute())
        router.setPath {
            HomeRoute()
        }

        #expect(handler.messages.isEmpty)
        #expect(handler.checks == 2)
    }

    @Test
    func disabledCategoryIsSkipped() {
        let handler = RecordingLogHandler()
        let router = StackRouter()
        let presentationOnly: Set<LogCategory> = [.presentation]
        let configuration = LogConfiguration(
            handler: handler,
            minimumLevel: .debug,
            categories: presentationOnly,
            format: .structured
        )
        router.setLogging(configuration)

        router.push(HomeRoute())
        router.present(SettingsRoute())

        let expectedCategories: [LogCategory] = [.presentation]
        #expect(handler.messages.map(\.category) == expectedCategories)
        #expect(handler.texts.first?.hasPrefix("presented ") == true)
    }

    @Test
    func changesAreLoggedAtInfoInTheirCategory() {
        let handler = RecordingLogHandler()
        let tabs = TabRouter(tabs: MainTab.homeAndShop, selection: .home)
        tabs.setLogging(LogConfiguration(handler: handler, minimumLevel: .info, format: .structured))

        tabs.select(.shop)
        tabs.router(for: .shop).push(HomeRoute())

        let expectedLevels: [LogLevel] = [.info, .info]
        #expect(handler.messages.map(\.level) == expectedLevels)
        let expectedCategories: [LogCategory] = [.tabs, .navigation]
        #expect(handler.messages.map(\.category) == expectedCategories)
        #expect(handler.texts.last?.hasSuffix(" flow=shop") == true)
    }

    @Test
    func childRouterSharesTheConfiguration() throws {
        let handler = RecordingLogHandler()
        let router = StackRouter()
        router.present(SettingsRoute())
        let child = try #require(router.presented)

        router.setLogging(LogConfiguration(handler: handler, minimumLevel: .info, format: .structured))
        child.push(HomeRoute())

        #expect(child.logging.minimumLevel == .info)
        let expectedTexts = ["pushed [HomeRoute] flow=\(child.flowID)"]
        #expect(handler.texts == expectedTexts)
    }

    @Test
    func privateValuesAreRedactedByDefault() {
        let handler = RecordingLogHandler()
        let router = StackRouter()
        router.setLogging(LogConfiguration(handler: handler, minimumLevel: .info, format: .structured))

        router.push(ProductRoute(id: 7))

        let expectedTexts = ["pushed [ProductRoute(id: <private>)] flow=main"]
        #expect(handler.texts == expectedTexts)
    }

    @Test
    func publicLogFieldsAreShown() {
        let handler = RecordingLogHandler()
        let router = StackRouter()
        router.setLogging(LogConfiguration(handler: handler, minimumLevel: .info, format: .structured))

        router.push(RouteFixtures.SearchRoute(id: 3, query: "shoes"))

        let text = handler.texts.first ?? ""
        #expect(text.contains("id: 3"))
        #expect(!text.contains("shoes"))
    }

    @Test
    func revealsPrivateValuesShowsEverything() {
        let handler = RecordingLogHandler()
        let router = StackRouter()
        let configuration = LogConfiguration(
            handler: handler,
            minimumLevel: .info,
            revealsPrivateValues: true,
            format: .structured
        )
        router.setLogging(configuration)

        router.push(ProductRoute(id: 7))

        let expectedTexts = ["pushed [ProductRoute(id: 7)] flow=main"]
        #expect(handler.texts == expectedTexts)
    }

    @Test
    func fallbackChangesSayWhereTheyCameFrom() {
        let handler = RecordingLogHandler()
        let router = StackRouter()
        router.push(HomeRoute())
        let navigationOnly: Set<LogCategory> = [.navigation]
        let configuration = LogConfiguration(
            handler: handler,
            minimumLevel: .info,
            categories: navigationOnly,
            format: .structured
        )
        router.setLogging(configuration)

        router.popTo(SettingsRoute(), else: .popToRoot)

        let expectedTexts = ["popped [HomeRoute] flow=main origin=fallback"]
        #expect(handler.texts == expectedTexts)
    }

    @Test
    func everyIssueIsLoggedWithItsCallSite() throws {
        let handler = RecordingLogHandler()
        let router = StackRouter()
        router.push(HomeRoute())
        let issuesOnly: Set<LogCategory> = [.issues]
        router.setLogging(LogConfiguration(handler: handler, categories: issuesOnly, format: .structured))

        let recoveredLine: UInt = #line + 1
        router.pop(count: 2)
        let failedLine: UInt = #line + 1
        router.popTo(SettingsRoute())

        let messages = handler.messages
        try #require(messages.count == 2)
        let expectedLevels: [LogLevel] = [.error, .fault]
        #expect(messages.map(\.level) == expectedLevels)
        let expectedLines = [recoveredLine, failedLine]
        #expect(messages.map(\.line) == expectedLines)
        #expect("\(messages[1].file)" == #fileID)
        #expect(messages[0].text.hasPrefix("notEnoughRoutes flow=main at=LoggingTests.swift:"))
        #expect(messages[1].text.contains("\n  "))
    }

    @Test
    func unchangedQueuedAndIgnoredCallsLogAtDebug() throws {
        let handler = RecordingLogHandler()
        let router = StackRouter()
        router.present(SettingsRoute())
        let child = try #require(router.presented)
        router.dismiss()
        router.push(HomeRoute())
        let navigationOnly: Set<LogCategory> = [.navigation]
        let configuration = LogConfiguration(
            handler: handler,
            minimumLevel: .debug,
            categories: navigationOnly,
            format: .structured
        )
        router.setLogging(configuration)
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

        let texts = handler.texts
        #expect(texts.count == 5)
        #expect(texts[0].hasPrefix("alreadyThere flow=main at=LoggingTests.swift:"))
        #expect(texts[1].hasPrefix("staleNavigator flow=settings at=LoggingTests.swift:"))
        #expect(texts[2].hasPrefix("pushed "))
        #expect(texts[3].hasPrefix("reentrantChange flow=main at=LoggingTests.swift:"))
        #expect(texts[4].hasPrefix("popped "))
    }

    @Test
    func registryProblemsAreLoggedAsErrors() {
        let handler = RecordingLogHandler()
        let router = StackRouter()
        router.setLogging(LogConfiguration(handler: handler, format: .structured))

        router.register(RouteFixtures.EmptyFormerKeyRoute.self)

        let expectedLevels: [LogLevel] = [.error]
        #expect(handler.messages.map(\.level) == expectedLevels)
        let expectedCategories: [LogCategory] = [.issues]
        #expect(handler.messages.map(\.category) == expectedCategories)
    }

    @Test
    func eachTransactionIsOneIntervalAlsoWhenItFails() {
        let handler = RecordingLogHandler()
        let router = StackRouter()
        router.setLogging(LogConfiguration(handler: handler, format: .structured))

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

    @Test
    func intervalsAreSkippedWhenTheCategoryIsOff() {
        let handler = RecordingLogHandler()
        let router = StackRouter()
        router.push(HomeRoute())
        let issuesOnly: Set<LogCategory> = [.issues]
        router.setLogging(LogConfiguration(handler: handler, categories: issuesOnly, format: .structured))

        router.push(HomeRoute())

        #expect(handler.intervals.isEmpty)
    }

    @Test
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

        #expect(Set(handler.texts).count == 50)
    }
}
