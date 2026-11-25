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

    @Test
    func didChangeMatchesEveryOutcome() {
        let failure = NavigationFailure(issue: issue)

        #expect(NavigationOutcome.applied.didChange)
        #expect(NavigationOutcome.recovered(issue, by: .popToRoot).didChange)
        #expect(!NavigationOutcome.alreadyThere.didChange)
        #expect(!NavigationOutcome.queued.didChange)
        #expect(!NavigationOutcome.ignored.didChange)
        #expect(!NavigationOutcome.failed(failure).didChange)
    }

    @Test
    func failureMatchesEveryOutcome() {
        let failure = NavigationFailure(issue: issue)

        #expect(NavigationOutcome.failed(failure).failure == failure)
        #expect(NavigationOutcome.applied.failure == nil)
        #expect(NavigationOutcome.recovered(issue, by: .popToRoot).failure == nil)
        #expect(NavigationOutcome.alreadyThere.failure == nil)
        #expect(NavigationOutcome.queued.failure == nil)
        #expect(NavigationOutcome.ignored.failure == nil)
    }

    @Test
    func failureDebugDescriptionAddsEachIssuesMessage() {
        let fallbackIssue = NavigationIssue(
            kind: .fallbackFailed,
            flow: FlowID("shop"),
            message: "The fallback push has no route to push.",
            file: "Shop/ShopCoordinator.swift",
            line: 42
        )
        let failure = NavigationFailure(issue: issue, fallback: .push, fallbackIssue: fallbackIssue)

        let lines = failure.debugDescription(revealingPrivateValues: false).split(separator: "\n")

        let expected = [
            Substring(failure.description),
            "  HomeRoute is not in the path [].",
            "  The fallback push has no route to push.",
        ]
        #expect(lines == expected)
    }

    @Test
    func levelsAndCategoriesReadAsTheirNames() {
        let levels: [LogLevel] = [.debug, .info, .notice, .error, .fault]
        let names = ["debug", "info", "notice", "error", "fault"]

        #expect(levels.map(\.description) == names)
        #expect(LogCategory.renderer.description == "renderer")
        #expect("\(LogCategory("checkout"))" == "checkout")
    }
}
