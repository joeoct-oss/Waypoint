//
//  StaleNavigatorTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import Understudy
import WaypointCore
import WaypointTestSupport

/// P10 to P12, P18 and P24: a late reply after its screen or flow closed changes nothing.
///
/// Each reply waits on a gate the test opens after closing, so the order is forced.
@Suite("Late replies and stale navigators")
@MainActor
struct StaleNavigatorTests {
    /// Each way an app's flow can close under a navigator.
    ///
    /// Conformances:
    /// - `CaseIterable` and `Sendable`, so a test runs once for each.
    enum FlowClose: CaseIterable, Sendable {
        /// The presenter dismisses the flow.
        case dismissedByPresenter
        /// The flow dismisses itself.
        case dismissedItself
        /// The flow's tab is removed.
        case tabRemoved
        /// The flow's router is released.
        case released
    }

    /// A navigator, the action that closes its flow, and the router to check afterwards.
    struct ClosingFlow {
        /// The navigator a view model kept.
        let navigation: StackNavigator

        /// Closes the navigator's flow.
        let close: @MainActor () -> Void

        /// The router whose state must not change, if one is left.
        let remaining: StackRouter?
    }

    @Test("A late reply after its flow closed changes nothing", arguments: FlowClose.allCases)
    func lateReplyAfterFlowClosedChangesNothing(_ way: FlowClose) async {
        let flow = makeClosingFlow(way)
        let gate = Gate()
        let reply = lateReply(from: flow.navigation, after: gate)

        flow.close()
        let afterClose = flow.remaining?.state
        await gate.open()
        let outcome = await reply.value

        #expect(outcome == .ignored)
        #expect(!flow.navigation.isActive)
        #expect(flow.remaining?.state == afterClose)
    }

    @Test("A late reply doesn't move the screen now in its place")
    func lateReplyDoesNotMoveTheScreenNowInItsPlace() async throws {
        let router = StackRouter(configuration: .permissive)
        router.present(CartRoute())
        let navigation = try #require(router.presented).navigator
        let gate = Gate()
        let reply = lateReply(from: navigation, after: gate)

        router.dismiss()
        router.present(CartRoute())
        await gate.open()
        let outcome = await reply.value

        let replacement = try #require(router.presented)
        #expect(outcome == .ignored)
        #expect(replacement.state.path.isEmpty)
    }

    @Test("A late reply after its screen was popped changes nothing")
    func lateReplyAfterScreenPoppedChangesNothing() async {
        let router = StackRouter(configuration: .permissive)
        let product = ItemRoute(id: 1)
        router.push(product)
        let navigation = router.navigator
        let gate = Gate()
        let reply = lateReply(from: navigation, after: gate)

        router.pop()
        router.push(product)
        await gate.open()
        let outcome = await reply.value

        let expected = [AnyRoute(product)]
        #expect(outcome == .ignored)
        #expect(router.state.path == expected)
    }

    @Test("The navigator of a popped screen reports inactive")
    func navigatorOfPoppedScreenReportsInactive() {
        let router = StackRouter(configuration: .permissive)
        router.push(ItemRoute(id: 1))
        let navigation = router.navigator
        #expect(navigation.isActive)

        router.pop()

        #expect(!navigation.isActive)
        #expect(router.isActive)
    }

    @Test("The navigator of a screen still on the stack stays active")
    func navigatorOfScreenStillOnStackStaysActive() {
        let router = StackRouter(configuration: .permissive)
        router.push(ItemRoute(id: 1))
        let navigation = router.navigator
        router.push(ItemRoute(id: 2))
        router.push(ItemRoute(id: 3))

        let outcome = navigation.push(ItemRoute(id: 4))

        let ids = [1, 2, 3, 4]
        let expected = ids.map { AnyRoute(ItemRoute(id: $0)) }
        #expect(navigation.isActive)
        #expect(outcome == .applied)
        #expect(router.state.path == expected)
    }

    @Test("The navigator of a popped screen can't pop the screen below")
    func navigatorOfPoppedScreenCannotPopTheScreenBelow() {
        let router = StackRouter(configuration: .permissive)
        router.push(ItemRoute(id: 1))
        router.push(ItemRoute(id: 2))
        let navigation = router.navigator
        router.pop()

        let outcome = navigation.pop()

        let expected = [AnyRoute(ItemRoute(id: 1))]
        #expect(outcome == .ignored)
        #expect(router.state.path == expected)
    }

    @Test("A scoped navigator stays tied to its screen")
    func scopedNavigatorKeepsItsScreen() {
        let router = StackRouter(configuration: .permissive)
        router.push(ItemRoute(id: 1))
        let navigation = router.navigator
        router.push(ItemRoute(id: 2))
        let shop = navigation.scoped(to: ShopFlow.self)

        router.popToRoot()

        #expect(!shop.isActive)
        #expect(shop.unscoped.push(ItemRoute(id: 3)) == .ignored)
        #expect(router.state.path.isEmpty)
    }

    @Test("A queued call of a screen popped first is ignored")
    func queuedCallOfAScreenPoppedFirstIsIgnored() {
        let router = StackRouter(configuration: .permissive)
        router.push(ItemRoute(id: 1))
        let navigation = router.navigator
        let late = Spy<NavigationOutcome, Void>()

        router.transaction { _ in
            router.pop()
            late(navigation.push(ItemRoute(id: 2)))
        }

        let queued: [NavigationOutcome] = [.queued]
        #expect(late.calls == queued)
        #expect(router.state.path.isEmpty)
    }

    @Test("A navigator reports inactive after its flow closes")
    func navigatorReportsInactiveAfterItsFlowCloses() throws {
        let router = StackRouter(configuration: .permissive)
        router.present(CartRoute())
        let navigation = try #require(router.presented).navigator(for: ShopFlow.self)
        #expect(navigation.isActive)

        router.dismiss()

        #expect(!navigation.isActive)
    }

    @Test("A router reports inactive after leaving the tree and ignores calls")
    func routerReportsInactiveAfterLeavingTheTree() throws {
        let router = StackRouter(configuration: .permissive)
        router.present(CartRoute())
        let child = try #require(router.presented)
        #expect(child.isActive)

        router.dismiss()
        let outcome = child.push(ItemRoute(id: 1))

        #expect(!child.isActive)
        #expect(outcome == .ignored)
    }

    @Test("A view model keeping a navigator doesn't keep a closed flow alive")
    func viewModelKeepingNavigatorDoesNotKeepClosedFlowAlive() {
        let router = StackRouter(configuration: .permissive)
        let model = presentAndKeepNavigator(on: router)
        #expect(model.closedFlow != nil)

        router.dismiss()

        #expect(model.closedFlow == nil)
        #expect(!model.navigation.isActive)
    }

    @Test("A stale call is logged at debug with its call site")
    func staleCallLogsStaleNavigatorWithItsLine() throws {
        let handler = RecordingLogHandler()
        let logging = LogConfiguration(handler: handler, minimumLevel: .debug, format: .structured)
        let router = StackRouter(configuration: NavigationConfiguration(logging: logging, registry: .permissive))
        router.push(ItemRoute(id: 1))
        let navigation = router.navigator
        router.pop()
        let callLine: UInt = 70_002

        navigation.push(ItemRoute(id: 2), line: callLine)

        let message = try #require(handler.messages.first { $0.text.hasPrefix("staleNavigator") })
        #expect(message.level == .debug)
        #expect(message.line == callLine)
        #expect("\(message.file)" == #fileID)
    }

    @Test("A transaction kept past its call changes nothing")
    func transactionKeptPastItsCallChangesNothing() {
        let router = StackRouter(configuration: .permissive)
        let kept = Spy<NavigationTransaction, Void>()
        router.transaction { transaction in
            kept(transaction)
        }

        let outcomes = kept.calls.map { transaction in
            transaction.push(ItemRoute(id: 1))
        }
        let after = router.push(ItemRoute(id: 2))

        let ignored: [NavigationOutcome] = [.ignored]
        let expected = [AnyRoute(ItemRoute(id: 2))]
        #expect(outcomes == ignored)
        #expect(after == .applied)
        #expect(router.state.path == expected)
    }

    /// A reply that waits for `gate`, then pushes from a background task, as a network reply
    /// would.
    private func lateReply(from navigation: StackNavigator, after gate: Gate) -> Task<NavigationOutcome, Never> {
        Task.detached {
            await gate.wait()
            return await navigation.push(ItemRoute(id: 99))
        }
    }

    /// A navigator of a flow that `way` closes.
    private func makeClosingFlow(_ way: FlowClose) -> ClosingFlow {
        switch way {
        case .dismissedByPresenter:
            let router = StackRouter(configuration: .permissive)
            router.present(CartRoute())
            let navigation = router.presented?.navigator ?? router.navigator
            return ClosingFlow(navigation: navigation, close: { router.dismiss() }, remaining: router)
        case .dismissedItself:
            let router = StackRouter(configuration: .permissive)
            router.present(CartRoute())
            let navigation = router.presented?.navigator ?? router.navigator
            return ClosingFlow(navigation: navigation, close: { navigation.dismissFlow() }, remaining: router)
        case .tabRemoved:
            let tabs = TabRouter(tabs: MainTab.homeAndShop, selection: MainTab.home, configuration: .permissive)
            let navigation = tabs.router(for: .shop).navigator
            let homeOnly = [MainTab.home]
            let home = tabs.router(for: .home)
            return ClosingFlow(navigation: navigation, close: { tabs.setTabs(homeOnly) }, remaining: home)
        case .released:
            let holder = RouterHolder()
            let navigation = makeReleasedNavigator(holder)
            return ClosingFlow(navigation: navigation, close: { holder.router = nil }, remaining: nil)
        }
    }

    /// A navigator whose router is gone once this returns, since only the holder points at it,
    /// weakly.
    private func makeReleasedNavigator(_ holder: RouterHolder) -> StackNavigator {
        let router = StackRouter(configuration: .permissive)
        holder.router = router
        return router.navigator
    }

    /// Presents a flow and gives a view model its navigator, keeping only a weak reference to
    /// the flow's router.
    private func presentAndKeepNavigator(on router: StackRouter) -> KeepingModel {
        router.present(CartRoute())
        let child = router.presented
        return KeepingModel(navigation: child?.navigator ?? router.navigator, closedFlow: child)
    }
}

/// A view model that keeps its navigator, and a weak reference to the flow it navigates.
@MainActor
final class KeepingModel {
    /// The navigator the model keeps.
    let navigation: StackNavigator

    /// The flow's router, while something else keeps it.
    weak var closedFlow: StackRouter?

    /// A model keeping `navigation`.
    init(navigation: StackNavigator, closedFlow: StackRouter?) {
        self.navigation = navigation
        self.closedFlow = closedFlow
    }
}
