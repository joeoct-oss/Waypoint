//
//  FlowEntryCatalogTests.swift
//  WaypointExampleTests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCatalog
import Testing
@testable import WaypointExample

// The Navigation Lab's catalog: twenty entries, each a flow of one kind on one branch. Only the
// three flows built so far run a demo; every other entry opens its own placeholder, which names the
// entry, until its flow is built. `LabTests.testBranchesOpenTheirPlaceholders` taps one
// placeholder on each branch; this checks every entry (planning #447).
struct FlowEntryCatalogTests {
    private static let entryCount = 20
    private static let runnableEntries: Set<FlowEntry> = [
        .detailPush,
        .tabs,
        .sheet,
    ]

    @Test("Every lab entry runs a demo or opens its placeholder")
    func everyEntryRunsADemoOrOpensItsPlaceholder() {
        let entries = FlowEntry.all

        #expect(entries.count == Self.entryCount)
        for entry in entries {
            let runsADemo = entry.demo != nil
            #expect(runsADemo == entry.isRunnable, "\(entry.placeholderLine)")
            #expect(runsADemo == Self.runnableEntries.contains(entry), "\(entry.placeholderLine)")
        }
    }

    @Test("Every placeholder names its own entry")
    func everyPlaceholderNamesItsOwnEntry() {
        let placeholders = FlowEntry.all.filter { !$0.isRunnable }

        let lines = Set(placeholders.map(\.placeholderLine))

        #expect(lines.count == placeholders.count)
        for entry in placeholders {
            #expect(entry.placeholderLine.contains(entry.branch.rawValue))
            #expect(entry.placeholderLine.contains(entry.flow.rawValue))
            #expect(entry.placeholderLine.contains(entry.kind.rawValue))
        }
    }
}
