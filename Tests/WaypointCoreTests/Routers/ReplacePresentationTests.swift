//
//  ReplacePresentationTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import WaypointTestSupport

@testable import WaypointCore

/// The `.replacePresentation` fallback and the outcome helpers (#145).
@Suite("Replace presentation")
@MainActor
struct ReplacePresentationTests {
    /// An issue for building outcomes by hand.
    let issue = NavigationIssue(
        kind: .alreadyPresenting,
        flow: FlowID("main"),
        message: "Already presenting settings.",
        file: #fileID,
        line: #line
    )

    @Test
    func replacePresentationDismissesThenPresents() throws {
        let router = StackRouter(configuration: .permissive)
        router.present(SettingsRoute())
        let replaced = try #require(router.presented)
        let batches = Recorder<[AppliedChange]>()
        router.tree.onApplied { changes in
            batches.record(changes)
        }

        let outcome = router.present(HomeRoute(), else: .replacePresentation)

        #expect(outcome.description == "recovered alreadyPresenting by=replacePresentation")
        let presented = try #require(router.presented)
        #expect(presented !== replaced)
        #expect(presented.rootRoute == AnyRoute(HomeRoute()))
        #expect(router.state.presentation?.route == AnyRoute(HomeRoute()))
        try #require(batches.count == 1)
        let changes = batches.values[0].map(\.change)
        #expect(changes.count == 2)
        #expect(changes.first == .dismissed(replaced.flowID))
        let origins = batches.values[0].map(\.origin)
        let expectedOrigins: [ChangeOrigin] = [.fallback, .fallback]
        #expect(origins == expectedOrigins)
    }

    @Test
    func replacePresentationKeepsTheCallsStyle() throws {
        let router = StackRouter(configuration: .permissive)
        router.present(SettingsRoute())

        router.present(HomeRoute(), style: .fullScreenCover, else: .replacePresentation)

        let presentation = try #require(router.state.presentation)
        #expect(presentation.style == .fullScreenCover)
    }

    @Test
    func replacePresentationDismissesNestedChildren() throws {
        let router = StackRouter(configuration: .permissive)
        router.present(SettingsRoute())
        let settings = try #require(router.presented)
        settings.present(ProductRoute(id: 1))
        let product = try #require(settings.presented)

        router.present(HomeRoute(), else: .replacePresentation)

        let home = try #require(router.presented)
        #expect(home.presented == nil)
        #expect(home.rootRoute == AnyRoute(HomeRoute()))
        #expect(settings.push(HomeRoute()) == .ignored)
        #expect(product.push(HomeRoute()) == .ignored)
    }

    @Test
    func replaceIsLoggedAsRecovered() {
        let handler = RecordingLogHandler()
        let issuesOnly: Set<LogCategory> = [.issues]
        let logging = LogConfiguration(handler: handler, categories: issuesOnly, format: .structured)
        let router = StackRouter(configuration: NavigationConfiguration(logging: logging, registry: .permissive))
        router.present(SettingsRoute())
        handler.removeAll()

        let outcome = router.present(HomeRoute(), else: .replacePresentation)

        #expect(outcome.recoveredIssue?.kind == .alreadyPresenting)
        let expectedLevels: [LogLevel] = [.error]
        #expect(handler.messages.map(\.level) == expectedLevels)
        #expect(handler.texts.first?.hasPrefix("alreadyPresenting flow=main") == true)
    }

    @Test
    func replacePresentationWorksAsRouterPolicy() throws {
        let tabs = TabRouter(tabs: MainTab.homeAndShop, selection: .home, configuration: .permissive)
        tabs.setFallback(.replacePresentation, for: .alreadyPresenting)
        tabs.present(SettingsRoute())

        let outcome = tabs.present(HomeRoute())

        #expect(outcome.recoveredIssue?.kind == .alreadyPresenting)
        let presented = try #require(tabs.presented)
        #expect(presented.rootRoute == AnyRoute(HomeRoute()))
    }

    @Test
    func replacePresentationWorksInATransaction() throws {
        let router = StackRouter(configuration: .permissive)
        router.present(SettingsRoute())

        let outcome = router.transaction {
            $0.push(ProductRoute(id: 1))
            $0.present(HomeRoute(), else: .replacePresentation)
        }

        #expect(outcome.recoveredIssue?.kind == .alreadyPresenting)
        let expectedPath = [AnyRoute(ProductRoute(id: 1))]
        #expect(router.state.path == expectedPath)
        let presented = try #require(router.presented)
        #expect(presented.rootRoute == AnyRoute(HomeRoute()))
    }

    @Test
    func replacePresentationOnlyAppliesToPresent() throws {
        let router = StackRouter(configuration: .permissive)
        router.present(SettingsRoute())
        let settings = try #require(router.presented)

        let outcome = router.pop(else: .replacePresentation)

        let failure = try #require(outcome.failure)
        #expect(failure.issue.kind == .emptyPath)
        #expect(failure.fallback == .replacePresentation)
        #expect(failure.fallbackIssue?.kind == .fallbackFailed)
        #expect(router.presented === settings)
    }

    @Test
    func replacedPresentationRollsBackWhenThePresentFails() throws {
        let router = StackRouter()
        router.register(SettingsRoute.self)
        router.present(SettingsRoute())
        let settings = try #require(router.presented)

        let outcome = router.present(HomeRoute(), else: .replacePresentation)

        let failure = try #require(outcome.failure)
        #expect(failure.issue.kind == .unregisteredRoute)
        #expect(router.presented === settings)
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
}
