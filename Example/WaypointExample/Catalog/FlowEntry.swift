//
//  FlowEntry.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// One of the twenty entry points: a flow of one kind, launched from one branch. Only `detailPush`,
// `tabs` and `sheet` run for real so far; the others open a placeholder.
//
// Conformances:
// - `Hashable`, so the app coordinator can keep an entry in its navigation path.
// - `Codable`, so an entry can sit in an account route, which Waypoint can save and restore.
nonisolated struct FlowEntry: Hashable, Codable {
    // The entries that run for real so far, all of the SwiftUI kind from the SwiftUI branch:
    // Detail push, Tabs and Sheet. The others open a placeholder until the APIs they need are
    // built.
    static let detailPush = FlowEntry(
        branch: .swiftUI,
        flow: .detailPush,
        kind: .swiftUI
    )
    static let tabs = FlowEntry(
        branch: .swiftUI,
        flow: .tabs,
        kind: .swiftUI
    )
    static let sheet = FlowEntry(
        branch: .swiftUI,
        flow: .sheet,
        kind: .swiftUI
    )

    static var all: [FlowEntry] {
        Branch.allCases.flatMap(entries(in:))
    }

    let branch: Branch
    let flow: ExampleFlow
    let kind: FlowKind

    var isRunnable: Bool {
        self == Self.detailPush || self == Self.tabs || self == Self.sheet
    }

    static func entries(in branch: Branch) -> [FlowEntry] {
        ExampleFlow.allCases.flatMap { flow in
            FlowKind.allCases.map { FlowEntry(branch: branch, flow: flow, kind: $0) }
        }
    }
}
