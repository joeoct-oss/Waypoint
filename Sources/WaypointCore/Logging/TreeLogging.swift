//
//  TreeLogging.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// Which part of the navigation tree is logged after each change.
///
/// Conformances:
/// - `Sendable`, so a configuration that holds it can be shared with the whole tree.
/// - `Equatable`, so tests can compare settings.
public enum TreeLogging: Sendable, Equatable {
    /// Nothing more than the changes. The default.
    case off
    /// One line with each changed stack, such as `shop       ≡ Product list › Product (id: 42, …)`.
    case changedStacks
    /// The whole tree, one flow per line, after every change.
    case wholeTree
}
