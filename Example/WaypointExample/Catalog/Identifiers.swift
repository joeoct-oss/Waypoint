//
//  Identifiers.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// Accessibility identifiers shared by the app and its UI tests. One pattern for every screen:
// `root.<branch>`, `<branch>.<flow>.<kind>` for an entry, and `placeholder.<flow>.<kind>` for the screen it opens.
enum Identifiers {
    static func branch(_ branch: Branch) -> String {
        "root.\(branch.rawValue)"
    }

    static func entry(_ entry: FlowEntry) -> String {
        "\(entry.branch.rawValue).\(entry.flow.rawValue).\(entry.kind.rawValue)"
    }

    static func placeholder(_ entry: FlowEntry) -> String {
        "placeholder.\(entry.flow.rawValue).\(entry.kind.rawValue)"
    }
}
