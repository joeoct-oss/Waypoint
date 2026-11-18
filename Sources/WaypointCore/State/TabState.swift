//
//  TabState.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// The state of a tab container.
///
/// `Tab` is usually an app enum, such as a `MainTab` with `home`, `shop` and `profile` cases.
///
/// Conformances:
/// - `NavigationStateValue`, so it can be saved and restored, compared, sent off the main actor and
///   described in logs.
/// - `Tab: NavigationTab`, the app's tab type.
public struct TabState<Tab: NavigationTab>: NavigationStateValue {
    /// The tabs, in display order.
    public let tabs: [Tab]

    /// The selected tab, always one of `tabs`.
    public let selection: Tab

    /// The flow presented above the whole tab container, if any.
    public let presentation: Presentation?

    /// The tabs, with `*` before the selected one: `[home, *shop, profile]`.
    public var description: String {
        debugDescription(revealingPrivateValues: false)
    }

    /// Creates a tab state.
    ///
    /// The selection is always one of the tabs: a `selection` that isn't one of `tabs` selects
    /// the first tab, and an empty `tabs` becomes `[selection]`.
    public init(tabs: [Tab], selection: Tab, presentation: Presentation? = nil) {
        let tabs = tabs.isEmpty ? [selection] : tabs
        self.tabs = tabs
        self.selection = tabs.contains(selection) ? selection : tabs[0]
        self.presentation = presentation
    }

    /// Decodes a saved tab state through ``init(tabs:selection:presentation:)``, so a saved
    /// selection that is no longer one of the tabs selects the first tab.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            tabs: try container.decode([Tab].self, forKey: .tabs),
            selection: try container.decode(Tab.self, forKey: .selection),
            presentation: try container.decodeIfPresent(Presentation.self, forKey: .presentation)
        )
    }

    /// The same state with another tab selected. A tab that isn't one of `tabs` selects the
    /// first tab.
    func withSelection(_ selection: Tab) -> TabState {
        TabState(tabs: tabs, selection: selection, presentation: presentation)
    }

    /// The same state with other tabs. If the selected tab is removed, the first tab is selected.
    func withTabs(_ tabs: [Tab]) -> TabState {
        TabState(tabs: tabs, selection: selection, presentation: presentation)
    }

    /// The same state with another presented flow.
    func withPresentation(_ presentation: Presentation?) -> TabState {
        TabState(tabs: tabs, selection: selection, presentation: presentation)
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
