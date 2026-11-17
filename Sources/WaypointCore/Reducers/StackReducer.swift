//
//  StackReducer.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// A change to one stack's path.
///
/// Conformances:
/// - `Sendable`, so commands can be queued and logged.
/// - `Equatable`, so tests can compare commands.
enum StackCommand: Sendable, Equatable {
    /// Push one route.
    case push(AnyRoute)
    /// Push several routes as one change.
    case pushMany([AnyRoute])
    /// Pop this many routes.
    case pop(count: Int)
    /// Pop to the last occurrence of a route.
    case popTo(AnyRoute)
    /// Empty the path.
    case popToRoot
    /// Replace the whole path.
    case setPath([AnyRoute])
}

/// Applies stack commands to a stack state. Pure: no routers, no globals.
enum StackReducer {
    /// Applies one command.
    ///
    /// `rootRoute` is the route of the stack's root screen, if it has one, so `popTo` it pops
    /// to the root instead of failing.
    static func reduce(_ state: StackState, _ command: StackCommand, rootRoute: AnyRoute?) -> Reduction<StackState> {
        switch command {
        case .push(let route):
            return push([route], onto: state)
        case .pushMany(let routes):
            return push(routes, onto: state)
        case .pop(let count):
            return pop(count, from: state)
        case .popTo(let route):
            return pop(to: route, in: state, rootRoute: rootRoute)
        case .popToRoot:
            return popToRoot(state)
        case .setPath(let path):
            return setPath(path, on: state)
        }
    }

    /// Appends routes in order.
    private static func push(_ routes: [AnyRoute], onto state: StackState) -> Reduction<StackState> {
        guard !routes.isEmpty else {
            return .unchanged
        }
        return .changed(state.withPath(state.path + routes), [.pushed(routes)])
    }

    /// Removes the top `count` routes. Zero or less changes nothing.
    private static func pop(_ count: Int, from state: StackState) -> Reduction<StackState> {
        guard count > 0 else {
            return .unchanged
        }
        guard !state.path.isEmpty else {
            return .rejected(.emptyPath)
        }
        guard count <= state.path.count else {
            return .rejected(.notEnoughRoutes(requested: count, available: state.path.count))
        }
        return keep(state.path.count - count, of: state)
    }

    /// Pops to the last occurrence of `route`, or to the root when it is the root screen's route.
    private static func pop(to route: AnyRoute, in state: StackState, rootRoute: AnyRoute?) -> Reduction<StackState> {
        if let index = state.path.lastIndex(of: route) {
            return keep(index + 1, of: state)
        }
        guard route == rootRoute else {
            return .rejected(.routeNotInPath(route))
        }
        return popToRoot(state)
    }

    /// Empties the path.
    private static func popToRoot(_ state: StackState) -> Reduction<StackState> {
        keep(0, of: state)
    }

    /// Replaces the path.
    private static func setPath(_ path: [AnyRoute], on state: StackState) -> Reduction<StackState> {
        guard path != state.path else {
            return .unchanged
        }
        return .changed(state.withPath(path), [.replaced(from: state.path, to: path)])
    }

    /// Keeps the bottom `count` routes and reports the rest as popped.
    private static func keep(_ count: Int, of state: StackState) -> Reduction<StackState> {
        guard count < state.path.count else {
            return .unchanged
        }
        let popped = Array(state.path[count...])
        return .changed(state.withPath(Array(state.path[..<count])), [.popped(popped)])
    }
}
