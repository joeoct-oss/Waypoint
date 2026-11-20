//
//  LabTool.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// The developer tools under the Lab's branches: the whole navigation tree as text, and the event
// log of every call and its outcome.
//
// Conformances:
// - `String` raw values, so each tool has a stable name in accessibility identifiers.
// - `Codable` (from the raw values), so a tool can sit in an account route.
// - `CaseIterable`, so the Lab lists every tool from this one declaration.
// - `Hashable` (from the raw values), so the account stack can push a tool's screen.
enum LabTool: String, CaseIterable, Codable {
    case navigationTree
    case eventLog

    var title: String {
        switch self {
        case .navigationTree:
            return "Navigation tree"
        case .eventLog:
            return "Event log"
        }
    }

    var summary: String {
        switch self {
        case .navigationTree:
            return "Every router and route in the app, as text"
        case .eventLog:
            return "Every call and what it did"
        }
    }

    var symbolName: String {
        switch self {
        case .navigationTree:
            return "point.3.connected.trianglepath.dotted"
        case .eventLog:
            return "list.bullet.rectangle"
        }
    }
}
