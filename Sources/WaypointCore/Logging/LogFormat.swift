//
//  LogFormat.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// How log lines are written.
///
/// ```text
/// readable:    shop       ▸ push Product (id: 42, …)
/// structured:  pushed [ProductRoute(id: 42, referrer: <private>)] flow=shop
/// ```
///
/// Conformances:
/// - `Sendable`, so a configuration that holds it can be shared with the whole tree.
/// - `Equatable`, so tests can compare formats.
public enum LogFormat: Sendable, Equatable {
    /// Sentences for people reading a console, with friendly route names. The default.
    case readable
    /// The stable `key=value` lines of ``NavigationDescribable``, for tools that parse logs.
    case structured
}
