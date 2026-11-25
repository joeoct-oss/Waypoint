//
//  LinkPushTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// Not guarded by `canImport(SwiftUI)`: what a link does on a tap uses only the core, so these run
// on Linux too. The SwiftUI view, `WaypointLink`, is checked by the example app's UI tests.

import Testing
import WaypointTestSupport

@testable import Waypoint
@testable import WaypointCore

/// What a `WaypointLink` does when tapped, and how a system link is reported (planning #349).
@Suite("Link push")
@MainActor
struct LinkPushTests {
    @Test("A link push goes through the router")
    func linkPushUsesRouterOutcome() {
        let router = StackRouter(configuration: .permissive)
        let link = LinkPush(route: ProductRoute(id: 1), fallback: nil)

        let outcome = link.run(on: router)

        #expect(outcome == .applied)
        let expectedPath = [AnyRoute(ProductRoute(id: 1))]
        #expect(router.state.path == expectedPath)
    }

    @Test("A link push is logged with its call site")
    func linkPushIsLoggedWithItsCallSite() {
        let handler = RecordingLogHandler()
        let logging = LogConfiguration.default
            .withHandler(handler)
            .withMinimumLevel(.debug)
        let configuration = NavigationConfiguration(
            logging: logging,
            registry: .permissive
        )
        let router = StackRouter(configuration: configuration)
        let link = LinkPush(
            route: ProductRoute(id: 1),
            fallback: nil,
            file: "Shop/ProductView.swift",
            line: 42
        )

        link.run(on: router)

        let pushLines = handler.messages.filter { message in
            message.category == .navigation && "\(message.file)" == "Shop/ProductView.swift" && message.line == 42
        }
        #expect(!pushLines.isEmpty)
    }

    @Test("A second tap while the push animates pushes nothing")
    func secondTapWhilePushAnimatesPushesNothing() {
        let router = StackRouter(configuration: .permissive)
        let link = LinkPush(route: ProductRoute(id: 1), fallback: nil)
        link.run(on: router)
        router.rendererDidStartPush(of: AnyRoute(ProductRoute(id: 1)))

        let outcome = link.run(on: router)

        #expect(outcome == .alreadyThere)
        #expect(router.state.path.count == 1)
    }

    @Test("A link push runs its fallback")
    func linkPushRunsItsFallback() {
        let router = StackRouter()
        router.register(HomeRoute.self)
        router.push(HomeRoute())
        let link = LinkPush(route: ProductRoute(id: 1), fallback: .popToRoot)

        let outcome = link.run(on: router)

        #expect(outcome?.description == "recovered unregisteredRoute by=popToRoot")
        #expect(router.state.path.isEmpty)
    }

    @Test("A link without a route is disabled and pushes nothing")
    func linkWithoutRouteIsDisabledAndPushesNothing() {
        let router = StackRouter(configuration: .permissive)
        let link = LinkPush<ProductRoute>(route: nil, fallback: nil)

        let outcome = link.run(on: router)

        #expect(!link.isEnabled(on: router))
        #expect(outcome == nil)
        #expect(router.state.path.isEmpty)
    }

    @Test("A link outside a stack is disabled")
    func linkOutsideStackIsDisabled() {
        let link = LinkPush(route: ProductRoute(id: 1), fallback: nil)

        let outcome = link.run(on: nil)

        #expect(!link.isEnabled(on: nil))
        #expect(outcome == nil)
    }

    @Test("A link with a route inside a stack is enabled")
    func linkWithRouteInsideStackIsEnabled() {
        let router = StackRouter(configuration: .permissive)
        let link = LinkPush(route: ProductRoute(id: 1), fallback: nil)

        #expect(link.isEnabled(on: router))
    }

    // Release builds use the default log settings (`.notice` and up), and nothing in the report
    // depends on `DEBUG`, so a system link is written to the app's log handler in release too.
    @Test("A system link is reported with the default log settings")
    func systemLinkIsLoggedAtErrorWithDefaultLogSettings() {
        let handler = RecordingLogHandler()
        let logging = LogConfiguration.default.withHandler(handler)
        let configuration = NavigationConfiguration(
            logging: logging,
            registry: .permissive
        )
        let router = StackRouter(configuration: configuration)
        router.push(ProductRoute(id: 1))
        let mirror = StackMirror(
            router: router,
            holdsTransitions: false,
            clock: ManualTransitionClock()
        )

        mirror.screenDidShow(count: 2)

        let issueLines = handler.messages.filter { message in
            message.category == .issues && message.level == .error
        }
        #expect(issueLines.count == 1)
        #expect(issueLines.first?.text.contains("WaypointLink") == true)
    }
}
