//
//  LogCategory.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// What part of Waypoint a log message is about.
///
/// A struct with static members rather than an enum, so add-ons can add their own categories
/// without a breaking change.
///
/// Conformances:
/// - `Hashable`, so categories can be kept in a set.
/// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
/// - `CustomStringConvertible`, so a category prints its name.
public struct LogCategory: Hashable, Sendable, CustomStringConvertible {
    /// Stack push, pop, replace and transactions.
    public static let navigation = LogCategory("navigation")

    /// Sheets, full-screen covers and dismissals.
    public static let presentation = LogCategory("presentation")

    /// Tab selection and per-tab stacks.
    public static let tabs = LogCategory("tabs")

    /// Coordinators, child flows, results and root switching.
    public static let flows = LogCategory("flows")

    /// Incoming links, URL matching and navigation plans.
    public static let links = LogCategory("links")

    /// Snapshots and restoring them.
    public static let restoration = LogCategory("restoration")

    /// Renderer sync, user-driven changes and the transition queue.
    public static let renderer = LogCategory("renderer")

    /// Every navigation issue, in one place.
    public static let issues = LogCategory("issues")

    /// The category's name, such as `navigation`.
    public let name: String

    /// The name.
    public var description: String {
        name
    }

    /// A category with this name.
    public init(_ name: String) {
        self.name = name
    }
}
