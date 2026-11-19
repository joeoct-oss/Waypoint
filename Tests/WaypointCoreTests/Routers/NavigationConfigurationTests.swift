//
//  NavigationConfigurationTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import WaypointTestSupport

@testable import WaypointCore

/// Settings for the whole tree are given once to the root router, and settings for one flow stay
/// on each router (see the Stack navigation article).
@Suite("Navigation configuration")
@MainActor
struct NavigationConfigurationTests {
    @Test
    func rootConfigurationReachesEveryRouter() throws {
        let handler = RecordingLogHandler()
        let failures = Recorder<NavigationFailure>()
        let configuration = NavigationConfiguration(
            logging: LogConfiguration(handler: handler, minimumLevel: .debug),
            maxQueuedChanges: 8,
            registry: .permissive,
            onNavigationFailure: { failure in
                failures.record(failure)
            }
        )
        let tabs = TabRouter(selection: MainTab.home, configuration: configuration)
        let shop = tabs.router(for: .shop)
        shop.present(SettingsRoute())
        let settings = try #require(shop.presented)

        settings.popTo(HomeRoute())

        let routers: [any NavigationRouter] = [tabs, shop, settings]
        let limits = routers.compactMap(maxQueuedChanges(of:))
        let expectedLimits = [8, 8, 8]
        #expect(limits == expectedLimits)
        #expect(settings.configuration.logging.handler is RecordingLogHandler)
        #expect(handler.routerTexts.contains { $0.contains("sheet settings") })
        #expect(failures.count == 1)
        #expect(failures.last?.issue.flow == settings.flowID)
    }

    @Test
    func childCannotChangeTreeWideSettings() throws {
        // Non-root routers have no setter for logging, the queue limit or the failure handler,
        // so a leaf can't change them: that part is checked by the compiler. The one tree-wide
        // value a child may add to is the registry, through `register`, which changes nothing
        // else.
        let configuration = NavigationConfiguration(maxQueuedChanges: 4, registry: .permissive)
        let router = StackRouter(configuration: configuration)
        router.present(SettingsRoute())
        let child = try #require(router.presented)

        child.register(ProductRoute.self)

        #expect(router.configuration.maxQueuedChanges == 4)
        #expect(router.configuration.logging.minimumLevel == .notice)
        #expect(router.configuration.registry.isRegistered(ProductRoute.self))
        #expect(router.registry.isRegistered(ProductRoute.self))
    }

    @Test
    func flowWideSettingsStillScopeToFlow() throws {
        let router = StackRouter(configuration: .permissive)
        router.present(SettingsRoute())
        let child = try #require(router.presented)
        let largeOnly: [SheetDetent] = [.large]
        let childDefaults = PresentationDefaults(sheet: SheetOptions(detents: largeOnly))

        child.setFallback(.popToRoot, for: .routeNotInPath)
        child.setPresentationDefaults(childDefaults)

        #expect(child.fallbackPolicy[.routeNotInPath] == .popToRoot)
        #expect(router.fallbackPolicy[.routeNotInPath] == nil)
        #expect(child.presentationDefaults == childDefaults)
        #expect(router.presentationDefaults == .default)
    }

    @Test
    func defaultsMatchTodayBehaviour() {
        let configuration = NavigationConfiguration.default
        let router = StackRouter()

        #expect(configuration.logging.handler is DisabledLogHandler)
        #expect(configuration.logging.minimumLevel == .notice)
        #expect(configuration.maxQueuedChanges == 32)
        #expect(configuration.registry.registeredTypes.isEmpty)
        #expect(configuration.onNavigationFailure == nil)
        #expect(router.configuration.maxQueuedChanges == 32)
        #expect(router.configuration.logging.handler is DisabledLogHandler)
    }

    @Test
    func registryInTheConfigurationIsKnownFromTheStart() {
        let registry = RouteRegistry().registering(ProductRoute.self)

        let router = StackRouter(configuration: NavigationConfiguration(registry: registry))

        #expect(router.registry.isRegistered(ProductRoute.self))
        #expect(router.push(ProductRoute(id: 1)) == .applied)
        #expect(router.push(HomeRoute()).failure?.issue.kind == .unregisteredRoute)
    }

    @Test
    func registryProblemsInTheConfigurationAreLogged() {
        let handler = RecordingLogHandler()
        let registry = RouteRegistry().registering(RouteFixtures.EmptyFormerKeyRoute.self)
        let logging = LogConfiguration(handler: handler, format: .structured)

        _ = StackRouter(configuration: NavigationConfiguration(logging: logging, registry: registry))

        let expectedLevels: [LogLevel] = [.error]
        #expect(handler.routerMessages.map(\.level) == expectedLevels)
    }

    @Test
    func tabRouterReportsAQueueLimitBelowOne() {
        let handler = RecordingLogHandler()
        let configuration = NavigationConfiguration(
            logging: LogConfiguration(handler: handler, format: .structured),
            maxQueuedChanges: 0
        )

        let tabs = TabRouter(tabs: MainTab.homeAndShop, selection: .home, configuration: configuration)

        #expect(tabs.configuration.maxQueuedChanges == 32)
        #expect(handler.routerTexts.first?.hasPrefix("invalidSetting flow=tabs") == true)
    }

    /// The queue limit a router reads, for the routers this suite knows.
    private func maxQueuedChanges(of router: any NavigationRouter) -> Int? {
        if let stack = router as? StackRouter {
            return stack.configuration.maxQueuedChanges
        }
        return (router as? TabRouter<MainTab>)?.configuration.maxQueuedChanges
    }
}
