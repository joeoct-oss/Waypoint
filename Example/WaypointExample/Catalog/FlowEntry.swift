//
//  FlowEntry.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// One of the twenty entry points: a flow of one kind, launched from one branch. Only
// `detailPush` runs for real so far; the others open a placeholder.
//
// Conformances:
// - `Hashable`, so the app coordinator can keep an entry in its navigation path.
// - `Codable`, so an entry can sit in an account route, which Waypoint can save and restore.
struct FlowEntry: Hashable, Codable {
    // The one entry that runs for real so far: Detail push of the SwiftUI kind, from the SwiftUI
    // branch. The others open a placeholder until the APIs they need are built.
    static let detailPush = FlowEntry(
        branch: .swiftUI,
        flow: .detailPush,
        kind: .swiftUI
    )

    static var all: [FlowEntry] {
        Branch.allCases.flatMap(entries(in:))
    }

    let branch: Branch
    let flow: ExampleFlow
    let kind: FlowKind

    var isRunnable: Bool {
        self == Self.detailPush
    }

    static func entries(in branch: Branch) -> [FlowEntry] {
        ExampleFlow.allCases.flatMap { flow in
            FlowKind.allCases.map { FlowEntry(branch: branch, flow: flow, kind: $0) }
        }
    }
}
