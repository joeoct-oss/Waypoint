//
//  DuplicatePushRule.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// What a stack does with a push of the route it is still pushing, such as the second tap of a
/// fast double tap on a row.
///
/// Set it on a router with ``StackRouter/setDuplicatePushRule(_:)`` or
/// ``TabRouter/setDuplicatePushRule(_:)``. It applies to that router and its children, unless a
/// child sets its own. Default: ``skipWhileInFlight``.
///
/// Conformances:
/// - `Sendable`, because the rule is read from the main actor and from tests.
/// - `Equatable`, so tests and the log can compare rules.
public enum DuplicatePushRule: Sendable, Equatable {
    /// A push of a route equal to the one whose push is still animating changes nothing and
    /// returns ``NavigationOutcome/alreadyThere``. A push of any other route goes ahead.
    case skipWhileInFlight

    /// Every push goes ahead, also a second push of the same route.
    case allow
}
