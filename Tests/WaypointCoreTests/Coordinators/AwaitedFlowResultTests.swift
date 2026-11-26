//
//  AwaitedFlowResultTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import Understudy
import WaypointCore
import WaypointTestSupport

/// Awaiting a child flow's result: `await router.present(child)` returns what `onFinish:` would
/// get, exactly once, and never waits for a flow that didn't start.
///
/// Each test that waits for a flow to start wakes on the router's observable state, as a
/// renderer does, so none of them sleeps.
@Suite("Awaiting child flow results", .timeLimit(.minutes(1)))
@MainActor
struct AwaitedFlowResultTests {
    /// The order number the checkout flow finishes with.
    private static let order = "A-1"

    @Test("An awaited present returns the value the flow finished with, and dismisses it")
    func awaitDeliversTheResult() async {
        let parent = StackRouter()
        let child = CheckoutFlowCoordinator()
        let awaiting = Task {
            await parent.present(child)
        }
        await until { parent.presented != nil }

        child.finish(with: Self.order)

        #expect(await awaiting.value == .finished(Self.order))
        #expect(parent.presented == nil)
    }

    @Test("An awaited present returns cancelled when the user swipes the flow away")
    func awaitReturnsCancelledAfterASwipe() async {
        let parent = StackRouter()
        let awaiting = Task {
            await parent.present(CheckoutFlowCoordinator(), style: .fullScreenCover)
        }
        await until { parent.presented != nil }

        parent.rendererDidDismiss()

        #expect(await awaiting.value == .cancelled)
    }

    @Test("The await and onFinish forms give the same one result", arguments: FlowEnding.allCases)
    func asyncAndClosureFormsBehaveTheSame(ending: FlowEnding) async {
        let closureResults = Spy<FlowResult<String>, Void>()
        let closureTree = Self.presentingTree()
        let closureChild = CheckoutFlowCoordinator()
        closureTree.parent.present(closureChild) { result in
            closureResults(result)
        }
        let awaitTree = Self.presentingTree()
        let awaitChild = CheckoutFlowCoordinator()
        let awaiting = Task {
            await awaitTree.parent.present(awaitChild)
        }
        await until { awaitTree.parent.presented != nil }

        ending.end(closureChild, presentedBy: closureTree.parent, in: closureTree.grandparent)
        ending.end(awaitChild, presentedBy: awaitTree.parent, in: awaitTree.grandparent)

        let awaited = await awaiting.value
        #expect(closureResults.callCount == 1)
        #expect(closureResults.calls.first == awaited)
    }

    @Test("A present whose fallback replaced the flow above waits for the new flow's result")
    func replacingFallbackWaitsForTheNewFlow() async {
        let parent = StackRouter(configuration: .permissive)
        parent.present(SettingsRoute())
        let child = CheckoutFlowCoordinator()
        let awaiting = Task {
            await parent.present(child, else: .replacePresentation)
        }
        await until { parent.presented === child.router }

        child.finish(with: Self.order)

        #expect(await awaiting.value == .finished(Self.order))
    }

    @Test("A refused lazy present never builds its child and returns cancelled at once")
    func awaitLazyPresentBuildsOnlyWhenItHappens() async {
        let gone = Self.endedRouter()
        let built = Spy<CheckoutFlowCoordinator, Void>()

        let result = await gone.present(style: .sheet) {
            let child = CheckoutFlowCoordinator()
            built(child)
            return child
        }

        #expect(result == .cancelled)
        #expect(built.calls.isEmpty)
    }

    @Test("A failed present returns cancelled at once, and the failure is still reported")
    func failedAwaitReturnsCancelledAtOnce() async {
        let failures = Spy<NavigationIssue.Kind, Void>()
        let configuration = NavigationConfiguration { failure in
            failures(failure.issue.kind)
        }
        let parent = StackRouter(configuration: configuration)

        let result = await parent.present(GivenRouterFlowCoordinator(given: parent))

        #expect(result == .cancelled)
        let expected: [NavigationIssue.Kind] = [.childRouterIsAncestor]
        #expect(failures.calls == expected)
    }

    @Test("A present on a router whose flow is gone returns cancelled at once")
    func ignoredAwaitReturnsCancelledAtOnce() async {
        let gone = Self.endedRouter()

        let result = await gone.present(CheckoutFlowCoordinator())

        #expect(result == .cancelled)
    }

    @Test("A present whose fallback started no flow returns cancelled at once")
    func recoveredAwaitThatStartedNothingReturnsCancelled() async {
        let parent = StackRouter(configuration: .permissive)
        parent.present(SettingsRoute())
        let settings = parent.presented

        let result = await parent.present(CheckoutFlowCoordinator(), else: .popToRoot)

        #expect(result == .cancelled)
        #expect(parent.presented === settings)
    }

    @Test("A skipped double tap on an awaited push returns cancelled at once, and keeps the first")
    func skippedPushReturnsCancelledAtOnce() async {
        let parent = StackRouter()
        let first = CheckoutFlowCoordinator()
        parent.push(first) { _ in }
        if let marker = parent.state.path.last {
            parent.rendererDidStartPush(of: marker)
        }

        let result = await parent.pushFlow(trigger: nil, else: nil, file: #fileID, line: #line) {
            CheckoutFlowCoordinator()
        }

        #expect(result == .cancelled)
        #expect(first.router.isActive)
    }

    @Test("An awaited push returns when the flow finishes, and when the user goes back below it")
    func awaitPushReturnsWhenThePushedFlowEnds() async {
        let parent = StackRouter()
        let finishing = CheckoutFlowCoordinator()
        let finished = Task {
            await parent.pushFlow(trigger: nil, else: nil, file: #fileID, line: #line) {
                finishing
            }
        }
        await until { !parent.state.path.isEmpty }
        finishing.finish(with: Self.order)
        #expect(await finished.value == .finished(Self.order))

        let leaving = CheckoutFlowCoordinator()
        let left = Task {
            await parent.pushFlow(trigger: nil, else: nil, file: #fileID, line: #line) {
                leaving
            }
        }
        await until { !parent.state.path.isEmpty }
        parent.rendererDidPop(toCount: 0)

        #expect(await left.value == .cancelled)
        #expect(parent.state.path.isEmpty)
    }

    @Test("A flow finished in the same change as its dismiss returns its value, once")
    func awaitDismissWhileFinishingDeliversOnce() async {
        let parent = StackRouter()
        let child = CheckoutFlowCoordinator()
        let awaiting = Task {
            await parent.present(child)
        }
        await until { parent.presented != nil }

        FlowEnding.dismissWhileFinishing.end(child, presentedBy: parent, in: parent)

        #expect(await awaiting.value == .finished(Self.order))
        #expect(parent.presented == nil)
    }

    @Test("Cancelling the awaiting task returns cancelled at once and leaves the flow up")
    func cancellingTheTaskLeavesTheFlowUp() async {
        let parent = StackRouter()
        let child = CheckoutFlowCoordinator()
        let awaiting = Task {
            await parent.present(child)
        }
        await until { parent.presented != nil }

        awaiting.cancel()

        #expect(await awaiting.value == .cancelled)
        #expect(parent.presented === child.router)
        #expect(child.router.isActive)
    }

    @Test("A flow whose awaiting task was cancelled is still dismissed, released and logged as not delivered")
    func cancelledAwaitingTaskStillCleansUpFlow() async {
        let handler = RecordingLogHandler()
        let flowsOnly: Set<LogCategory> = [.flows]
        let logging = LogConfiguration(
            handler: handler,
            minimumLevel: .debug,
            categories: flowsOnly,
            format: .structured
        )
        let parent = StackRouter(configuration: NavigationConfiguration(logging: logging))
        // `var` because a weak reference must be one: it reads `nil` once the flow lets go.
        weak var weakChild: CheckoutFlowCoordinator?
        weak var weakRouter: StackRouter?
        let awaiting = Task {
            await parent.present(style: .sheet) {
                let child = CheckoutFlowCoordinator()
                weakChild = child
                weakRouter = child.router
                return child
            }
        }
        await until { parent.presented != nil }
        awaiting.cancel()
        #expect(await awaiting.value == .cancelled)

        weakChild?.finish(with: Self.order)
        // Waypoint lets an ended flow's router go at the next navigation call.
        parent.popToRoot()

        #expect(parent.presented == nil)
        #expect(weakChild == nil)
        #expect(weakRouter == nil)
        let notDelivered = handler.texts.filter { text in
            text.hasPrefix("result not delivered flow=main coordinator=CheckoutFlowCoordinator result=finished")
        }
        #expect(notDelivered.count == 1)
        #expect(!handler.texts.joined().contains(Self.order))
    }

    @Test("Cancelling the task after the flow finished keeps the value")
    func cancelAfterFinishKeepsTheValue() async {
        let parent = StackRouter()
        let child = CheckoutFlowCoordinator()
        let awaiting = Task {
            await parent.present(child)
        }
        await until { parent.presented != nil }

        child.finish(with: Self.order)
        awaiting.cancel()

        #expect(await awaiting.value == .finished(Self.order))
    }

    @Test("A task that was already cancelled still starts the flow and returns cancelled")
    func alreadyCancelledTaskStartsTheFlowAndReturnsCancelled() async {
        let parent = StackRouter()
        let child = CheckoutFlowCoordinator()
        let started = Spy<Bool, Void>()
        let awaiting = Task {
            withUnsafeCurrentTask { task in
                task?.cancel()
            }
            let result = await parent.present(child)
            started(parent.presented === child.router)
            return result
        }

        #expect(await awaiting.value == .cancelled)
        let expected = [true]
        #expect(started.calls == expected)
    }

    @Test("An await from a background task gets the flow's result")
    func awaitFromBackgroundTaskGetsTheResult() async {
        let parent = StackRouter()
        let child = CheckoutFlowCoordinator()
        let awaiting = Task.detached {
            await parent.present(child)
        }
        await until { parent.presented != nil }

        child.finish(with: Self.order)

        #expect(await awaiting.value == .finished(Self.order))
    }

    @Test("An awaited present on a tab router returns the result of the flow over the tabs")
    func awaitOnTabRouterPresentsOverTheTabs() async {
        let tabs = TabRouter(selection: MainTab.home)
        let child = CheckoutFlowCoordinator()
        let finished = Task {
            await tabs.present(child)
        }
        await until { tabs.presented != nil }
        child.finish(with: Self.order)
        #expect(await finished.value == .finished(Self.order))

        let swiped = Task {
            await tabs.present(style: .sheet) {
                CheckoutFlowCoordinator()
            }
        }
        await until { tabs.presented != nil }
        tabs.rendererDidDismiss()

        #expect(await swiped.value == .cancelled)
    }

    /// A permissive root that presents a flow, whose router is the parent a test presents from.
    private static func presentingTree() -> (grandparent: StackRouter, parent: StackRouter) {
        let grandparent = StackRouter(configuration: .permissive)
        let outer = CheckoutFlowCoordinator()
        grandparent.present(outer) { _ in }
        return (grandparent, outer.router)
    }

    /// The router of a flow that was dismissed, whose calls are ignored.
    private static func endedRouter() -> StackRouter {
        let parent = StackRouter()
        let child = CheckoutFlowCoordinator()
        parent.present(child) { _ in }
        let router = child.router
        parent.dismiss()
        return router
    }
}
