//
//  NavigationValues.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// A value the navigation keeps and looks up: routes, flow names, route keys, sheet sizes and
/// the app's tabs.
///
/// Every type that conforms gets these conformances for the same reasons:
/// - `Hashable`, so the router can compare values, find them in a path and key dictionaries by
///   them.
/// - `Codable`, so navigation state that holds them can be saved, restored and built from links.
/// - `Sendable`, so they can leave the main actor for logging, analytics and saving.
///
/// Like `Codable`, this is a name for the three protocols together, so a type that already has
/// them conforms without saying so.
public typealias NavigationValue = Hashable & Codable & Sendable

/// A value the navigation reports: changes, outcomes, issues, failures and fallbacks.
///
/// Every type that conforms gets these conformances for the same reasons:
/// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
/// - `Equatable`, so tests and the router can compare values.
/// - `NavigationDescribable`, for a short, stable, private-by-default description in logs,
///   events and test failures.
public typealias NavigationRecord = Sendable & Equatable & NavigationDescribable

/// A part of the navigation state: a ``NavigationRecord`` that can also be saved and restored.
///
/// Every type that conforms gets the ``NavigationRecord`` conformances, and:
/// - `Codable`, so the state can be saved, restored and logged.
public typealias NavigationStateValue = NavigationRecord & Codable

/// A tab of a tab container, usually an app enum.
///
/// A tab type says it is one with one word: `enum MainTab: String, NavigationTab, CaseIterable`.
/// It is a ``NavigationValue``, for the same reasons: tabs are compared and selected, the
/// selection is saved and restored, and tab events leave the main actor. A `String` raw value
/// gives each case a readable name in logs and saved state, and `CaseIterable` lets
/// `TabRouter(selection:)` show every case.
public protocol NavigationTab: NavigationValue { }
