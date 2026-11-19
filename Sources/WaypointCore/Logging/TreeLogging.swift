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
    /// One more line with each changed stack in full, such as
    /// `Waypoint  shop       stack    root › Product list › Product (id: 42, …)`. Change lines
    /// already end with the stack, so most apps leave this off.
    case changedStacks
    /// The whole tree, one flow per line, after every change.
    case wholeTree
}
