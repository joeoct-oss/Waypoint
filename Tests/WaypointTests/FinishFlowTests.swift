//
//  FinishFlowTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// Not guarded by `canImport(SwiftUI)`: the action uses only the core, so these run on Linux too.
// `@FinishFlow` reads the stack's router from the environment and hands it to the lookup these
// tests call.

import Testing
import Understudy
import WaypointCore
import WaypointTestSupport

@testable import Waypoint

/// A view finishing the flow it is in with `@FinishFlow`.
@Suite("Finishing a flow from a view", .timeLimit(.minutes(1)))
@MainActor
struct FinishFlowTests {
    /// The review the flow finishes with.
    private static let review = "Five stars"

    /// Where the wrapper in these tests is declared.
    private let site = WrapperSite(file: "Lab/ReviewView.swift", line: 12)

    @Test("A view's finish action ends its presented flow with the value, and dismisses it")
    func finishFlowActionFinishesItsFlow() {
        let parent = StackRouter()
        let child = ReviewFlowCoordinator()
        let results = Spy<FlowResult<String>, Void>()
        parent.present(child) { result in
            results(result)
        }
        let finishFlow = action(in: child.router)

        let outcome = finishFlow(Self.review)

        #expect(outcome == .applied)
        let expected: [FlowResult<String>] = [.finished(Self.review)]
        #expect(results.calls == expected)
        #expect(parent.presented == nil)
        #expect(!finishFlow.isActive)
    }

    @Test("A view in a sheet the flow presented finishes the flow under it")
    func finishFromASheetInsideTheFlowFinishesTheFlow() throws {
        let parent = StackRouter(configuration: .permissive)
        let child = ReviewFlowCoordinator()
        let results = Spy<FlowResult<String>, Void>()
        parent.present(child) { result in
            results(result)
        }
        child.router.present(SettingsRoute())
        let sheet = try #require(child.router.presented)

        action(in: sheet)(Self.review)

        let expected: [FlowResult<String>] = [.finished(Self.review)]
        #expect(results.calls == expected)
        #expect(parent.presented == nil)
    }

    @Test("A view's finish action ends its pushed flow and pops back below it")
    func finishFlowActionFinishesAPushedFlow() {
        let parent = StackRouter()
        let child = ReviewFlowCoordinator()
        let results = Spy<FlowResult<String>, Void>()
        parent.push(child) { result in
            results(result)
        }

        action(in: child.router)(Self.review)

        let expected: [FlowResult<String>] = [.finished(Self.review)]
        #expect(results.calls == expected)
        #expect(parent.state.path.isEmpty)
    }

    @Test("An awaiting parent gets the value a view finished the flow with")
    func awaitingParentGetsTheViewsValue() async {
        let parent = StackRouter()
        let child = ReviewFlowCoordinator()
        let awaiting = Task {
            await parent.present(child)
        }
        await until { parent.presented != nil }

        action(in: child.router)(Self.review)

        #expect(await awaiting.value == .finished(Self.review))
    }

    @Test("Outside its flow the action changes nothing and reports where it is declared")
    func finishFlowOutsideItsFlowIsReported() throws {
        let parent = StackRouter()
        let other = OtherFlowCoordinator()
        let results = Spy<FlowResult<Int>, Void>()
        parent.present(other) { result in
            results(result)
        }
        let finishFlow = action(in: other.router)

        let outcome = finishFlow(Self.review)

        let failure = try #require(outcome.failure)
        #expect(failure.issue.kind == .noRouterInScope)
        let expectedMessage =
            "@FinishFlow(ReviewFlowCoordinator.self) in ReviewView.swift:12 found no "
            + "ReviewFlowCoordinator flow above its view, so nothing finished. Use it in a screen of "
            + "ReviewFlowCoordinator's flow, or call finish(with:) on the coordinator."
        #expect(failure.issue.message == expectedMessage)
        #expect(results.calls.isEmpty)
        #expect(parent.presented === other.router)
        #expect(!finishFlow.isActive)
    }

    @Test("With no stack above the view the action fails and reports the missing stack")
    func finishFlowWithNoStackIsReported() throws {
        let reported = Spy<NavigationIssue.Kind, Void>()
        let finishFlow = NavigatorLookup.finishFlow(ReviewFlowCoordinator.self, nil, site: site) { issue in
            reported(issue.kind)
        }

        let outcome = finishFlow(Self.review)

        let failure = try #require(outcome.failure)
        #expect(failure.issue.kind == .noRouterInScope)
        let expectedMessage =
            "@FinishFlow(ReviewFlowCoordinator.self) in ReviewView.swift:12 found no "
            + "Waypoint stack above its view. Show the view inside a WaypointStack, or add "
            + ".waypointPreview() in its preview."
        #expect(failure.issue.message == expectedMessage)
        let expected: [NavigationIssue.Kind] = [.noRouterInScope]
        #expect(reported.calls == expected)
    }

    @Test("Once its flow has ended the action is ignored and delivers nothing more")
    func finishAfterTheFlowEndedIsIgnored() {
        let parent = StackRouter()
        let child = ReviewFlowCoordinator()
        let results = Spy<FlowResult<String>, Void>()
        parent.present(child) { result in
            results(result)
        }
        let finishFlow = action(in: child.router)
        parent.dismiss()

        let outcome = finishFlow(Self.review)

        #expect(outcome == .ignored)
        let expected: [FlowResult<String>] = [.cancelled]
        #expect(results.calls == expected)
    }

    /// The action `@FinishFlow(ReviewFlowCoordinator.self)` gives a view whose stack is `router`.
    private func action(in router: StackRouter) -> FinishFlowAction<String> {
        NavigatorLookup.finishFlow(ReviewFlowCoordinator.self, router, site: site) { _ in }
    }
}

/// A flow that ends with a review.
///
/// Conformances:
/// - `FlowCoordinating`, so a parent can start it and a view can finish it.
@MainActor
private final class ReviewFlowCoordinator: FlowCoordinating {
    /// The review it finishes with.
    typealias Output = String
}

/// Another flow, which a review screen is not in.
///
/// Conformances:
/// - `FlowCoordinating`, so a parent can start it.
@MainActor
private final class OtherFlowCoordinator: FlowCoordinating {
    /// It finishes with a number.
    typealias Output = Int
}
