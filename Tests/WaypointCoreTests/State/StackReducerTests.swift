//
//  StackReducerTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import WaypointTestSupport

@testable import WaypointCore

/// The pure stack reducer (#45): every command, its changes, and the commands it refuses.
@Suite("Stack reducer")
struct StackReducerTests {
    let home = AnyRoute(HomeRoute())

    let product1 = AnyRoute(ProductRoute(id: 1))

    let product2 = AnyRoute(ProductRoute(id: 2))

    let settings = AnyRoute(SettingsRoute())

    @Test
    func pushAppendsRoute() {
        let result = reduce([], .push(product1))

        #expect(result == .changed(StackState(path: [product1]), [.pushed([product1])]))
    }

    @Test
    func pushManyAppendsInOrder() {
        let result = reduce([home], .pushMany([product1, product2]))

        #expect(result == .changed(StackState(path: [home, product1, product2]), [.pushed([product1, product2])]))
    }

    @Test
    func pushManyWithNoRoutesIsAlreadyThere() {
        #expect(reduce([home], .pushMany([])) == .unchanged)
    }

    @Test
    func popRemovesLast() {
        let result = reduce([home, product1], .pop(count: 1))

        #expect(result == .changed(StackState(path: [home]), [.popped([product1])]))
    }

    @Test
    func popCountRemovesN() {
        let result = reduce([home, product1, product2], .pop(count: 2))

        #expect(result == .changed(StackState(path: [home]), [.popped([product1, product2])]))
    }

    @Test
    func popOnEmptyPathIsRejected() {
        #expect(reduce([], .pop(count: 1)) == .rejected(.emptyPath))
    }

    @Test
    func popTooManyIsRejectedWithCounts() {
        #expect(reduce([home], .pop(count: 3)) == .rejected(.notEnoughRoutes(requested: 3, available: 1)))
    }

    @Test
    func popZeroIsAlreadyThere() {
        #expect(reduce([home], .pop(count: 0)) == .unchanged)
    }

    @Test
    func popToRouteStopsAtLastMatch() {
        let result = reduce([product1, settings, product1, product2], .popTo(product1))

        #expect(result == .changed(StackState(path: [product1, settings, product1]), [.popped([product2])]))
    }

    @Test
    func popToMissingRouteIsRejected() {
        #expect(reduce([home, product1], .popTo(settings)) == .rejected(.routeNotInPath(settings)))
    }

    @Test
    func popToTopRouteIsAlreadyThere() {
        #expect(reduce([home, product1], .popTo(product1)) == .unchanged)
    }

    @Test
    func popToRootScreenPopsToRoot() {
        let result = StackReducer.reduce(StackState(path: [product1, product2]), .popTo(home), rootRoute: home)

        #expect(result == .changed(StackState(path: []), [.popped([product1, product2])]))
    }

    @Test
    func popToRootEmptiesPath() {
        let result = reduce([home, product1], .popToRoot)

        #expect(result == .changed(StackState(path: []), [.popped([home, product1])]))
    }

    @Test
    func popToRootOnEmptyPathIsAlreadyThere() {
        #expect(reduce([], .popToRoot) == .unchanged)
    }

    @Test
    func setPathReplacesAndReportsReplaced() {
        let result = reduce([home], .setPath([product1, product2]))

        let expected = StackState(path: [product1, product2])
        #expect(result == .changed(expected, [.replaced(from: [home], to: [product1, product2])]))
    }

    @Test
    func setPathToSamePathIsAlreadyThere() {
        #expect(reduce([home, product1], .setPath([home, product1])) == .unchanged)
    }

    @Test
    func reducerKeepsPresentation() {
        let presentation = Presentation(style: .sheet, flow: FlowID("filter"))
        let state = StackState(path: [home], presentation: presentation)

        let result = StackReducer.reduce(state, .push(product1), rootRoute: nil)

        let expected = StackState(path: [home, product1], presentation: presentation)
        #expect(result == .changed(expected, [.pushed([product1])]))
    }

    // Reduces a command on a stack with this path and no root route.
    private func reduce(_ path: [AnyRoute], _ command: StackCommand) -> Reduction<StackState> {
        StackReducer.reduce(StackState(path: path), command, rootRoute: nil)
    }
}
