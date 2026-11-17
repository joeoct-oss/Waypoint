//
//  Reduction.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// What a pure reducer did with one command.
///
/// Conformances:
/// - `State: Equatable`, so reductions can be compared in tests.
/// - `Equatable`, so tests can compare reductions.
enum Reduction<State: Equatable>: Equatable {
    /// The command changed the state. The changes are in order.
    case changed(State, [NavigationChange])
    /// The state already matched. Nothing changed.
    case unchanged
    /// The command would break a rule. The state is unchanged.
    case rejected(Rejection)
}

/// Why a reducer refused a command. The router turns it into a `NavigationIssue`.
///
/// Conformances:
/// - `Equatable`, so tests can compare rejections.
/// - `Sendable`, so rejections can be reported off the main actor.
enum Rejection: Equatable, Sendable {
    /// A pop on an empty path.
    case emptyPath
    /// A pop of more routes than the path holds.
    case notEnoughRoutes(requested: Int, available: Int)
    /// A `popTo` route that is not in the path.
    case routeNotInPath(AnyRoute)
    /// A tab that is not one of the container's tabs, by name.
    case unknownTab(String)
    /// A tab list with no tabs.
    case noTabs
    /// A presentation while the flow already presents this one.
    case alreadyPresenting(FlowID)
}
