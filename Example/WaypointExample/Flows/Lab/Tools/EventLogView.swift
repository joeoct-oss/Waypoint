//
//  EventLogView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCatalog
import ExampleDesignSystem
import ExampleServices
import SwiftUI
import Waypoint

// The Lab's event log (DB-02): every navigation call the routers logged, newest first, with its
// outcome, level, time, line and call site. The filter shows all calls or one outcome, and Share
// sends the shown lines as text. Route values show only in debug builds, as in the console.
struct EventLogView: View {
    private static let filters: [EventLogFilter] = [
        .all,
        .outcome(.applied),
        .outcome(.recovered),
        .outcome(.failed),
    ]

    let entries: [EventLogEntry]

    @State private var filter = EventLogFilter.all

    private var shownEntries: [EventLogEntry] {
        entries.filter(filter.includes)
    }

    private var sharedText: String {
        shownEntries
            .map(\.sharedLine)
            .joined(separator: "\n")
    }

    var body: some View {
        List {
            filterSection
            entriesSection
        }
        .exampleList()
        .accessibilityIdentifier(Identifiers.eventLog)
        .toolbar { shareItem }
    }

    private var filterSection: some View {
        Section {
            Picker("Show", selection: $filter) {
                ForEach(Self.filters, id: \.self) { filter in
                    Text(filter.title)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier(Identifiers.eventLogFilter)
        }
    }

    @ViewBuilder
    private var entriesSection: some View {
        if shownEntries.isEmpty {
            emptyState
        } else {
            Section {
                ForEach(shownEntries) { entry in
                    EventLogRow(entry: entry)
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No calls yet",
            systemImage: "list.bullet.rectangle",
            description: Text("Move around the shop, then come back.")
        )
    }

    private var shareItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            ShareLink(item: sharedText) {
                Label("Share log", systemImage: "square.and.arrow.up")
            }
        }
    }
}

// What the event log shows: every call, or the calls with one outcome.
//
// Conformances:
// - `Hashable`, so the segmented picker can select a filter.
enum EventLogFilter: Hashable {
    case all
    case outcome(EventOutcome)

    var title: String {
        switch self {
        case .all:
            return "All"
        case .outcome(let outcome):
            return outcome.title.capitalized
        }
    }

    func includes(_ entry: EventLogEntry) -> Bool {
        switch self {
        case .all:
            return true
        case .outcome(let outcome):
            return entry.outcome == outcome
        }
    }
}

// One call in the event log: its outcome in color, its level and time, its line and call site.
struct EventLogRow: View {
    let entry: EventLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.extraSmall) {
            header
            Text(entry.text)
                .font(Typography.code)
                .foregroundStyle(Palette.text.color)
            Text(entry.callSite)
                .font(Typography.code)
                .foregroundStyle(Palette.textTertiary.color)
        }
        .padding(.vertical, Spacing.extraSmall)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(Identifiers.eventLogEntry(entry.outcome.title))
    }

    private var header: some View {
        HStack(spacing: Spacing.small) {
            Text(entry.outcome.title)
                .font(Typography.label)
                .foregroundStyle(entry.outcome.tint.color)
            Text(entry.level.description)
                .font(Typography.label)
                .foregroundStyle(Palette.textTertiary.color)
            Text(entry.date, format: .dateTime.hour().minute().second())
                .font(Typography.label)
                .foregroundStyle(Palette.textTertiary.color)
        }
    }
}

extension EventOutcome {
    var tint: ColorToken {
        switch self {
        case .applied:
            return Palette.success
        case .recovered:
            return Palette.warning
        case .failed:
            return Palette.error
        case .queued, .ignored, .alreadyThere:
            return Palette.textTertiary
        }
    }
}

extension EventLogEntry {
    var sharedLine: String {
        "\(level.description) \(outcome.title) \(text) \(callSite)"
    }
}
