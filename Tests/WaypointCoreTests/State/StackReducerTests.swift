//
//  StackReducerTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import WaypointTestSupport

@testable import WaypointCore

/// The pure stack reducer (planning #298): every command, its changes, and the commands it refuses.
@Suite("Stack reducer")
struct StackReducerTests {
    let home = AnyRoute(HomeRoute())

    let product1 = AnyRoute(ProductRoute(id: 1))

    let product2 = AnyRoute(ProductRoute(id: 2))

    let settings = AnyRoute(SettingsRoute())

    @Test
    func pushAppendsRoute() {
        let empty: [AnyRoute] = []
        let pushed = [product1]

        let result = reduce(empty, .push(product1))

        let changes: [NavigationChange] = [.pushed(pushed)]
        #expect(result == .changed(StackState(path: pushed), changes))
    }

    @Test
    func pushManyAppendsInOrder() {
        let path = [home]
        let pushed = [product1, product2]

        let result = reduce(path, .pushMany(pushed))

        let expected = StackState(path: path + pushed)
        let changes: [NavigationChange] = [.pushed(pushed)]
        #expect(result == .changed(expected, changes))
    }

    @Test
    func pushManyWithNoRoutesIsAlreadyThere() {
        let path = [home]
        let none: [AnyRoute] = []

        #expect(reduce(path, .pushMany(none)) == .unchanged)
    }

    @Test
    func popRemovesLast() {
        let kept = [home]
        let popped = [product1]

        let result = reduce(kept + popped, .pop(count: 1))

        let changes: [NavigationChange] = [.popped(popped)]
        #expect(result == .changed(StackState(path: kept), changes))
    }

    @Test
    func popCountRemovesN() {
        let kept = [home]
        let popped = [product1, product2]

        let result = reduce(kept + popped, .pop(count: 2))

        let changes: [NavigationChange] = [.popped(popped)]
        #expect(result == .changed(StackState(path: kept), changes))
    }

    @Test
    func popOnEmptyPathIsRejected() {
        let empty: [AnyRoute] = []

        #expect(reduce(empty, .pop(count: 1)) == .rejected(.emptyPath))
    }

    @Test
    func popTooManyIsRejectedWithCounts() {
        let path = [home]

        #expect(reduce(path, .pop(count: 3)) == .rejected(.notEnoughRoutes(requested: 3, available: 1)))
    }

    @Test
    func popZeroIsAlreadyThere() {
        let path = [home]

        #expect(reduce(path, .pop(count: 0)) == .unchanged)
    }

    @Test
    func popToRouteStopsAtLastMatch() {
        let kept = [product1, settings, product1]
        let popped = [product2]

        let result = reduce(kept + popped, .popTo(product1))

        let changes: [NavigationChange] = [.popped(popped)]
        #expect(result == .changed(StackState(path: kept), changes))
    }

    @Test
    func popToMissingRouteIsRejected() {
        let path = [home, product1]

        #expect(reduce(path, .popTo(settings)) == .rejected(.routeNotInPath(settings)))
    }

    @Test
    func popToTopRouteIsAlreadyThere() {
        let path = [home, product1]

        #expect(reduce(path, .popTo(product1)) == .unchanged)
    }

    @Test
    func popToRootScreenPopsToRoot() {
        let popped = [product1, product2]
        let empty: [AnyRoute] = []

        let result = StackReducer.reduce(StackState(path: popped), .popTo(home), rootRoute: home)

        let changes: [NavigationChange] = [.popped(popped)]
        #expect(result == .changed(StackState(path: empty), changes))
    }

    @Test
    func popToRootEmptiesPath() {
        let popped = [home, product1]
        let empty: [AnyRoute] = []

        let result = reduce(popped, .popToRoot)

        let changes: [NavigationChange] = [.popped(popped)]
        #expect(result == .changed(StackState(path: empty), changes))
    }

    @Test
    func popToRootOnEmptyPathIsAlreadyThere() {
        let empty: [AnyRoute] = []

        #expect(reduce(empty, .popToRoot) == .unchanged)
    }

    @Test
    func setPathReplacesAndReportsReplaced() {
        let old = [home]
        let new = [product1, product2]

        let result = reduce(old, .setPath(new))

        let changes: [NavigationChange] = [.replaced(from: old, to: new)]
        #expect(result == .changed(StackState(path: new), changes))
    }

    @Test
    func setPathToSamePathIsAlreadyThere() {
        let path = [home, product1]

        #expect(reduce(path, .setPath(path)) == .unchanged)
    }

    @Test
    func reducerKeepsPresentation() {
        let presentation = Presentation(style: .sheet, flow: FlowID("filter"))
        let path = [home]
        let pushed = [product1]
        let state = StackState(path: path, presentation: presentation)

        let result = StackReducer.reduce(state, .push(product1), rootRoute: nil)

        let expected = StackState(path: path + pushed, presentation: presentation)
        let changes: [NavigationChange] = [.pushed(pushed)]
        #expect(result == .changed(expected, changes))
    }

    // Reduces a command on a stack with this path and no root route.
    private func reduce(_ path: [AnyRoute], _ command: StackCommand) -> Reduction<StackState> {
        StackReducer.reduce(StackState(path: path), command, rootRoute: nil)
    }
}
