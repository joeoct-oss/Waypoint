//
//  LogFormat.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// How log lines are written.
///
/// ```text
/// readable:    Waypoint  shop       push     Product (id: 42, …)    │ root › Product (id: 42, …)
/// structured:  pushed [ProductRoute(id: 42, referrer: <private>)] flow=shop
/// ```
///
/// Conformances:
/// - `Sendable`, so a configuration that holds it can be shared with the whole tree.
/// - `Equatable`, so tests can compare formats.
public enum LogFormat: Sendable, Equatable {
    /// One aligned line per change for people reading a console: the action, then the stack on
    /// screen, with friendly route names. The default.
    case readable
    /// The stable `key=value` lines of ``NavigationDescribable``, for tools that parse logs.
    case structured
}
