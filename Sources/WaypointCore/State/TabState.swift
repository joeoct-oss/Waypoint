//
//  TabState.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// The state of a tab container.
///
/// `Tab` is usually an app enum, such as a `MainTab` with `home`, `shop` and `profile` cases.
///
/// Conformances:
/// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
/// - `Equatable`, so tests and the router can compare values.
/// - `Codable`, so it can be saved, restored and logged.
/// - `Tab: Hashable`, to select and compare tabs.
/// - `Tab: Codable`, so the selection is saved and restored.
/// - `Tab: Sendable`, so tab events can leave the main actor.
/// - `NavigationDescribable`, for a short, stable, private-by-default description in logs, events and test failures.
public struct TabState<Tab: Hashable & Codable & Sendable>: Sendable, Equatable, Codable, NavigationDescribable {
    /// The tabs, in display order.
    public var tabs: [Tab]

    /// The selected tab. The router keeps it one of `tabs`.
    public var selection: Tab

    /// The flow presented above the whole tab container, if any.
    public var presentation: Presentation?

    /// The tabs, with `*` before the selected one: `[home, *shop, profile]`.
    public var description: String {
        debugDescription(revealingPrivateValues: false)
    }

    /// Creates a tab state.
    public init(tabs: [Tab], selection: Tab, presentation: Presentation? = nil) {
        self.tabs = tabs
        self.selection = selection
        self.presentation = presentation
    }

    /// The same line, then `+` and the presentation if there is one.
    public func debugDescription(revealingPrivateValues: Bool) -> String {
        let names = tabs.map { tab in
            tab == selection ? "*\(DescriptionFormat.name(of: tab))" : DescriptionFormat.name(of: tab)
        }
        let list = "[\(names.joined(separator: ", "))]"
        guard let presentation else {
            return list
        }
        return "\(list) + \(presentation.debugDescription(revealingPrivateValues: revealingPrivateValues))"
    }
}
