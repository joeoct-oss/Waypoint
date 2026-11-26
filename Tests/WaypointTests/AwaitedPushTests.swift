//
//  AwaitedPushTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// Not guarded by `canImport(SwiftUI)`: the push forms use only the core, so these run on Linux
// too. The fixture's screen exists only where SwiftUI is.

#if canImport(SwiftUI)
    import SwiftUI
#endif
import Testing
import Understudy
import Waypoint
import WaypointTestSupport

/// Awaiting a pushed flow's result with `await router.push(child)` (planning #314).
///
/// SwiftUI cancels a screen's `.task` when a pushed screen or a full-screen cover hides it. The
/// tests that cancel the awaiting task do what SwiftUI does then.
@Suite("Awaiting pushed flow results", .timeLimit(.minutes(1)))
@MainActor
struct AwaitedPushTests {
    /// The review the flow finishes with.
    private static let review = "Five stars"

    @Test("An awaited push returns the value the pushed flow finished with, and pops it")
    func awaitPushReturnsTheFinishedValue() async {
        let parent = StackRouter()
        let child = PushedReviewCoordinator()
        let awaiting = Task {
            await parent.push(child)
        }
        await until { !parent.state.path.isEmpty }

        child.finish(with: Self.review)

        #expect(await awaiting.value == .finished(Self.review))
        #expect(parent.state.path.isEmpty)
    }

    @Test("A lazy awaited push returns cancelled when the user goes back below the flow")
    func awaitPushReturnsWhenThePushedFlowEnds() async {
        let parent = StackRouter()
        let built = Spy<PushedReviewCoordinator, Void>()
        let awaiting = Task {
            await parent.push {
                let child = PushedReviewCoordinator()
                built(child)
                return child
            }
        }
        await until { !parent.state.path.isEmpty }

        parent.rendererDidPop(toCount: 0)

        #expect(await awaiting.value == .cancelled)
        #expect(built.callCount == 1)
    }

    @Test("An awaited push on a router whose flow is gone builds nothing and returns cancelled at once")
    func refusedAwaitPushReturnsCancelledAtOnce() async {
        let parent = StackRouter()
        let presented = PushedReviewCoordinator()
        parent.present(presented) { _ in }
        let gone = presented.router
        parent.dismiss()
        let built = Spy<PushedReviewCoordinator, Void>()

        let result = await gone.push {
            let child = PushedReviewCoordinator()
            built(child)
            return child
        }

        #expect(result == .cancelled)
        #expect(built.calls.isEmpty)
    }

    @Test("Cancelling the task that awaits a push keeps the pushed flow up, and it still ends")
    func awaitFromAScreensTaskKeepsThePushedFlowUp() async {
        let parent = StackRouter()
        let child = PushedReviewCoordinator()
        let screenTask = Task {
            await parent.push(child)
        }
        await until { !parent.state.path.isEmpty }

        screenTask.cancel()

        #expect(await screenTask.value == .cancelled)
        #expect(child.router.isActive)
        #expect(!parent.state.path.isEmpty)
        child.finish(with: Self.review)
        #expect(parent.state.path.isEmpty)
    }

    @Test("Cancelling the task that awaits a full-screen cover keeps the cover up")
    func awaitFromAScreensTaskKeepsTheCoverUp() async {
        let parent = StackRouter()
        let child = PushedReviewCoordinator()
        let screenTask = Task {
            await parent.present(child, style: .fullScreenCover)
        }
        await until { parent.presented != nil }

        screenTask.cancel()

        #expect(await screenTask.value == .cancelled)
        #expect(parent.presented === child.router)
        #expect(parent.state.presentation?.style == .fullScreenCover)
    }
}

/// A pushed flow of one screen that ends with a review.
///
/// Conformances:
/// - `FlowCoordinator`, so a parent can push it and await its result.
@MainActor
private final class PushedReviewCoordinator: FlowCoordinator {
    /// The review it finishes with.
    typealias Output = String

    #if canImport(SwiftUI)
        /// The review form.
        var root: some View {
            Text("Write a review")
        }
    #endif
}
