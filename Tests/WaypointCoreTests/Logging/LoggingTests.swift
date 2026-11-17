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

/// The logging seam: levels, categories, privacy, issues and intervals (#77).
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
        router.setLogging(LogConfiguration(handler: handler, minimumLevel: .debug))
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
        router.setLogging(LogConfiguration(handler: handler, minimumLevel: .notice))

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
        router.setLogging(LogConfiguration(handler: handler, minimumLevel: .debug, categories: [.presentation]))

        router.push(HomeRoute())
        router.present(SettingsRoute())

        #expect(handler.messages.map(\.category) == [.presentation])
        #expect(handler.texts.first?.hasPrefix("presented ") == true)
    }

    @Test
    func changesAreLoggedAtInfoInTheirCategory() {
        let handler = RecordingLogHandler()
        let tabs = TabRouter(tabs: [MainTab.home, .shop], selection: .home)
        tabs.setLogging(LogConfiguration(handler: handler, minimumLevel: .info))

        tabs.select(.shop)
        tabs.router(for: .shop).push(HomeRoute())

        #expect(handler.messages.map(\.level) == [.info, .info])
        #expect(handler.messages.map(\.category) == [.tabs, .navigation])
        #expect(handler.texts.last?.hasSuffix(" flow=shop") == true)
    }

    @Test
    func childRouterSharesTheConfiguration() throws {
        let handler = RecordingLogHandler()
        let router = StackRouter()
        router.present(SettingsRoute())
        let child = try #require(router.presented)

        router.setLogging(LogConfiguration(handler: handler, minimumLevel: .info))
        child.push(HomeRoute())

        #expect(child.logging.minimumLevel == .info)
        #expect(handler.texts == ["pushed [HomeRoute] flow=\(child.flowID)"])
    }

    @Test
    func privateValuesAreRedactedByDefault() {
        let handler = RecordingLogHandler()
        let router = StackRouter()
        router.setLogging(LogConfiguration(handler: handler, minimumLevel: .info))

        router.push(ProductRoute(id: 7))

        #expect(handler.texts == ["pushed [ProductRoute(id: <private>)] flow=main"])
    }

    @Test
    func publicLogFieldsAreShown() {
        let handler = RecordingLogHandler()
        let router = StackRouter()
        router.setLogging(LogConfiguration(handler: handler, minimumLevel: .info))

        router.push(RouteFixtures.SearchRoute(id: 3, query: "shoes"))

        let text = handler.texts.first ?? ""
        #expect(text.contains("id: 3"))
        #expect(!text.contains("shoes"))
    }

    @Test
    func revealsPrivateValuesShowsEverything() {
        let handler = RecordingLogHandler()
        let router = StackRouter()
        router.setLogging(LogConfiguration(handler: handler, minimumLevel: .info, revealsPrivateValues: true))

        router.push(ProductRoute(id: 7))

        #expect(handler.texts == ["pushed [ProductRoute(id: 7)] flow=main"])
    }

    @Test
    func fallbackChangesSayWhereTheyCameFrom() {
        let handler = RecordingLogHandler()
        let router = StackRouter()
        router.push(HomeRoute())
        router.setLogging(LogConfiguration(handler: handler, minimumLevel: .info, categories: [.navigation]))

        router.popTo(SettingsRoute(), else: .popToRoot)

        #expect(handler.texts == ["popped [HomeRoute] flow=main origin=fallback"])
    }

    @Test
    func everyIssueIsLoggedWithItsCallSite() throws {
        let handler = RecordingLogHandler()
        let router = StackRouter()
        router.push(HomeRoute())
        router.setLogging(LogConfiguration(handler: handler, categories: [.issues]))

        let recoveredLine: UInt = #line + 1
        router.pop(count: 2)
        let failedLine: UInt = #line + 1
        router.popTo(SettingsRoute())

        let messages = handler.messages
        try #require(messages.count == 2)
        #expect(messages.map(\.level) == [.error, .fault])
        #expect(messages.map(\.line) == [recoveredLine, failedLine])
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
        router.setLogging(LogConfiguration(handler: handler, minimumLevel: .debug, categories: [.navigation]))
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
        router.setLogging(LogConfiguration(handler: handler))

        router.register(RouteFixtures.EmptyFormerKeyRoute.self)

        #expect(handler.messages.map(\.level) == [.error])
        #expect(handler.messages.map(\.category) == [.issues])
    }

    @Test
    func eachTransactionIsOneIntervalAlsoWhenItFails() {
        let handler = RecordingLogHandler()
        let router = StackRouter()
        router.setLogging(LogConfiguration(handler: handler))

        router.transaction {
            $0.push(HomeRoute())
            $0.push(ProductRoute(id: 1))
        }
        router.popTo(SettingsRoute())

        let first = LogInterval(name: "transaction", category: .navigation, id: 1)
        let second = LogInterval(name: "transaction", category: .navigation, id: 2)
        #expect(handler.intervals == [.began(first), .ended(first), .began(second), .ended(second)])
    }

    @Test
    func intervalsAreSkippedWhenTheCategoryIsOff() {
        let handler = RecordingLogHandler()
        let router = StackRouter()
        router.push(HomeRoute())
        router.setLogging(LogConfiguration(handler: handler, categories: [.issues]))

        router.push(HomeRoute())

        #expect(handler.intervals.isEmpty)
    }

    @Test
    func recordingHandlerKeepsOrderAcrossThreads() async {
        let handler = RecordingLogHandler()

        await withTaskGroup(of: Void.self) { group in
            for index in 0..<50 {
                group.addTask {
                    handler.log(LogMessage(level: .info, category: .navigation, text: "\(index)", file: #fileID, line: #line))
                }
            }
        }

        #expect(Set(handler.texts).count == 50)
    }
}
