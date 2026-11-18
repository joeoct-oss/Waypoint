//
//  OutcomeDescriptionTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import WaypointTestSupport

@testable import WaypointCore

/// Pins how outcomes, issues and failures print (see the Descriptions article).
@Suite("Outcome descriptions")
struct OutcomeDescriptionTests {
    let issue = NavigationIssue(
        kind: .routeNotInPath,
        flow: FlowID("shop"),
        message: "HomeRoute is not in the path [].",
        file: "Shop/ShopCoordinator.swift",
        line: 42
    )

    @Test
    func outcomeDescriptions() {
        #expect(NavigationOutcome.applied.description == "applied")
        #expect(NavigationOutcome.alreadyThere.description == "alreadyThere")
        #expect(NavigationOutcome.queued.description == "queued")
        #expect(NavigationOutcome.ignored.description == "ignored")
        #expect(NavigationOutcome.failed(NavigationFailure(issue: issue)).description == "failed routeNotInPath")
    }

    @Test
    func issueDescriptionNamesFlowAndCallSite() {
        #expect(issue.description == "routeNotInPath flow=shop at=ShopCoordinator.swift:42")
        let expected = "routeNotInPath flow=shop at=ShopCoordinator.swift:42\n  HomeRoute is not in the path []."
        #expect(issue.debugDescription == expected)
    }

    @Test
    func failureDescription() {
        let failure = NavigationFailure(issue: issue)

        #expect(failure.description == "failed routeNotInPath flow=shop at=ShopCoordinator.swift:42")
    }

    @Test
    func issuesCompareByCallSite() {
        let same = NavigationIssue(
            kind: .routeNotInPath,
            flow: FlowID("shop"),
            message: issue.message,
            file: "Shop/ShopCoordinator.swift",
            line: 42
        )
        let other = NavigationIssue(
            kind: .routeNotInPath,
            flow: FlowID("shop"),
            message: issue.message,
            file: "Shop/ShopCoordinator.swift",
            line: 43
        )

        #expect(issue != other)
        #expect(issue == same)
    }

    @Test
    @MainActor
    func issueMessagesKeepRouteFieldsPrivate() {
        let router = StackRouter(configuration: .permissive)
        router.push(ProductRoute(id: 7))

        let message = router.popTo(SettingsRoute()).failure?.issue.message ?? ""

        #expect(message.hasPrefix("SettingsRoute is not in the path [ProductRoute(id: <private>)]."))
        #expect(!message.contains("7"))
    }
}
