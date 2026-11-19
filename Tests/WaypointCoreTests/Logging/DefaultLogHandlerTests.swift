//
//  DefaultLogHandlerTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import WaypointTestSupport

@testable import WaypointCore

/// What the renderers add to logging (#78): the default handler they may replace, the `push`
/// interval and the held-change line. The unified log handler itself is tested on the Mac, in
/// `WaypointOSLogTests`.
@Suite("Default log handler")
@MainActor
struct DefaultLogHandlerTests {
    /// A root router whose tree logs with `logging`, and a permissive registry.
    private static func router(_ logging: LogConfiguration) -> StackRouter {
        StackRouter(configuration: NavigationConfiguration(logging: logging, registry: .permissive))
    }

    @Test
    func configurationWithoutHandlerUsesTheDefault() {
        let handler = RecordingLogHandler()

        #expect(LogConfiguration.default.usesDefaultHandler)
        #expect(LogConfiguration(minimumLevel: .debug).usesDefaultHandler)
        #expect(LogConfiguration.default.withMinimumLevel(.debug).withFormat(.structured).usesDefaultHandler)
        #expect(!LogConfiguration.disabled.usesDefaultHandler)
        #expect(!LogConfiguration(handler: handler).usesDefaultHandler)
        #expect(!LogConfiguration.default.withHandler(handler).usesDefaultHandler)
        #expect(!LogConfiguration(handler: handler).withMinimumLevel(.debug).usesDefaultHandler)
    }

    @Test
    func installReplacesTheDefaultHandlerOnce() {
        let installed = RecordingLogHandler()
        let later = RecordingLogHandler()
        let router = Self.router(LogConfiguration(minimumLevel: .debug, format: .structured))

        #expect(router.installDefaultLogHandler { installed })
        #expect(!router.installDefaultLogHandler { later })
        router.push(HomeRoute())

        #expect(router.configuration.logging.handler is RecordingLogHandler)
        #expect(router.configuration.logging.minimumLevel == .debug)
        #expect(installed.routerTexts == ["pushed [HomeRoute] flow=main"])
        #expect(later.messages.isEmpty)
    }

    @Test
    func installKeepsTheAppsHandler() {
        let apps = RecordingLogHandler()
        let installed = RecordingLogHandler()
        let router = Self.router(LogConfiguration(handler: apps, minimumLevel: .debug, format: .structured))

        #expect(!router.installDefaultLogHandler { installed })
        router.push(HomeRoute())

        #expect(apps.routerTexts == ["pushed [HomeRoute] flow=main"])
        #expect(installed.messages.isEmpty)
    }

    @Test
    func installKeepsLoggingDisabled() {
        let installed = RecordingLogHandler()
        let router = Self.router(.disabled)

        #expect(!router.installDefaultLogHandler { installed })
        router.push(HomeRoute())

        #expect(router.configuration.logging.handler is DisabledLogHandler)
        #expect(installed.checks == 0)
    }

    @Test
    func installOnAChildCoversTheWholeTree() throws {
        let installed = RecordingLogHandler()
        let root = Self.router(LogConfiguration(minimumLevel: .debug, format: .structured))
        root.present(SettingsRoute())
        let child = try #require(root.presented)

        #expect(child.installDefaultLogHandler { installed })
        installed.removeAll()
        root.push(HomeRoute())

        #expect(installed.routerTexts == ["pushed [HomeRoute] flow=main"])
    }

    @Test
    func installOnATabContainerCoversTheWholeTree() {
        let installed = RecordingLogHandler()
        let logging = LogConfiguration(minimumLevel: .debug, format: .structured)
        let configuration = NavigationConfiguration(logging: logging)
        let tabs = TabRouter(tabs: MainTab.homeAndShop, selection: .home, configuration: configuration)

        #expect(tabs.installDefaultLogHandler { installed })

        #expect(tabs.configuration.logging.handler is RecordingLogHandler)
    }

    @Test
    func pushIsMeasuredAsARendererInterval() {
        let handler = RecordingLogHandler()
        let router = Self.router(LogConfiguration(handler: handler, minimumLevel: .debug))
        let route = AnyRoute(ProductRoute(id: 1))
        handler.removeAll()

        router.rendererDidStartPush(of: route)
        router.rendererDidEndPush(of: route)

        let push = LogInterval(name: "push", category: .renderer, id: 1)
        let expected: [RecordingLogHandler.IntervalEvent] = [.began(push), .ended(push)]
        #expect(handler.intervals == expected)
    }

    @Test
    func replacedPushEndsBeforeTheNewOneBegins() {
        let handler = RecordingLogHandler()
        let router = Self.router(LogConfiguration(handler: handler, minimumLevel: .debug))
        let first = AnyRoute(ProductRoute(id: 1))
        let second = AnyRoute(ProductRoute(id: 2))

        router.rendererDidStartPush(of: first)
        router.rendererDidStartPush(of: second)
        router.rendererDidEndPush(of: first)
        router.rendererDidEndPush(of: second)

        let firstPush = LogInterval(name: "push", category: .renderer, id: 1)
        let secondPush = LogInterval(name: "push", category: .renderer, id: 2)
        let expected: [RecordingLogHandler.IntervalEvent] = [
            .began(firstPush),
            .ended(firstPush),
            .began(secondPush),
            .ended(secondPush),
        ]
        #expect(handler.intervals == expected)
    }

    @Test
    func pushIsNotMeasuredWhenRendererIsOff() {
        let handler = RecordingLogHandler()
        let navigationOnly: Set<LogCategory> = [.navigation]
        let logging = LogConfiguration(handler: handler, minimumLevel: .debug, categories: navigationOnly)
        let router = Self.router(logging)
        let route = AnyRoute(ProductRoute(id: 1))

        router.rendererDidStartPush(of: route)
        router.rendererDidEndPush(of: route)

        #expect(handler.intervals.isEmpty)
    }

    @Test
    func heldChangeIsLoggedAtDebugInRenderer() {
        let handler = RecordingLogHandler()
        let structured = Self.router(LogConfiguration(handler: handler, minimumLevel: .debug, format: .structured))
        let readable = Self.router(LogConfiguration(handler: handler, minimumLevel: .debug))

        structured.rendererDidHoldChange(for: .milliseconds(450))
        readable.rendererDidHoldChange(for: .milliseconds(450))

        #expect(handler.routerMessages.map(\.level) == [.debug, .debug])
        #expect(handler.routerMessages.map(\.category) == [.renderer, .renderer])
        #expect(handler.routerTexts[0] == "heldChange flow=main wait=450ms")
        #expect(handler.routerTexts[1] == "Waypoint  main       hold     waits 450 ms for the running transition")
    }

    @Test
    func heldChangeIsQuietAtNotice() {
        let handler = RecordingLogHandler()
        let router = Self.router(LogConfiguration(handler: handler))

        router.rendererDidHoldChange(for: .milliseconds(450))

        #expect(handler.routerMessages.isEmpty)
    }
}
