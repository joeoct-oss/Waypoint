//
//  EventLog.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Foundation
import Observation
import WaypointCore

// The Lab's event log: every navigation call the routers logged, newest first, with its outcome.
// `EventLogHandler` fills it from the routers' log, so the screen shows exactly what the console
// shows, one line per call. It keeps the newest `capacity` entries.
@Observable
final class EventLog {
    private static let capacity = 300

    // `var` because each logged call adds an entry at the front. Only `record(_:)` changes it.
    private(set) var entries: [EventLogEntry]

    init() {
        entries = []
    }

    func record(_ entry: EventLogEntry) {
        entries = Array(([entry] + entries).prefix(Self.capacity))
    }
}

// One navigation call in the event log.
//
// Conformances:
// - `Identifiable`, so the log's list tells its rows apart.
// - `Hashable`, so SwiftUI can compare rows.
nonisolated struct EventLogEntry: Identifiable, Hashable {
    let id: UUID
    let date: Date
    let level: LogLevel
    let outcome: EventOutcome
    let text: String
    let callSite: String
}

// What a logged call did, as the event log names and colors it.
//
// Conformances:
// - `CaseIterable`, so the log's filters list the outcomes.
// - `Hashable`, so a filter can be picked and compared.
nonisolated enum EventOutcome: CaseIterable, Hashable {
    case applied
    case recovered
    case queued
    case ignored
    case alreadyThere
    case failed

    var title: String {
        switch self {
        case .applied:
            return "applied"
        case .recovered:
            return "recovered"
        case .queued:
            return "queued"
        case .ignored:
            return "ignored"
        case .alreadyThere:
            return "alreadyThere"
        case .failed:
            return "failed"
        }
    }
}

// Turns the routers' log lines into event log entries. An issue is recovered at `.error` and failed
// at `.fault`. A one-line change at `.debug` is applied, unless its verb says it was skipped,
// queued or ignored. Journey boxes and other multi-line lines are left to the console.
//
// Conformances:
// - `LogHandler`, so `AppLogHandler` can pass it the routers' log.
nonisolated struct EventLogHandler: LogHandler {
    private static let changeCategories: Set<LogCategory> = [
        .navigation,
        .presentation,
        .tabs,
        .flows,
    ]

    private static let outcomesByVerb: [String: EventOutcome] = [
        "same": .alreadyThere,
        "skip": .alreadyThere,
        "queue": .queued,
        "ignore": .ignored,
    ]

    // Lines that say what a router waits for or holds, not what a call did.
    private static let skippedVerbs: Set<String> = [
        "hold",
        "stack",
    ]

    let events: EventLog

    func isEnabled(level: LogLevel, category: LogCategory) -> Bool {
        category == .issues || Self.changeCategories.contains(category)
    }

    func log(_ message: LogMessage) {
        guard let entry = Self.makeEntry(for: message) else {
            return
        }
        Task { @MainActor in
            events.record(entry)
        }
    }

    func beginInterval(_ interval: LogInterval) { }

    func endInterval(_ interval: LogInterval) { }

    private static func makeEntry(for message: LogMessage) -> EventLogEntry? {
        guard let outcome = outcome(of: message) else {
            return nil
        }
        return EventLogEntry(
            id: UUID(),
            date: Date(),
            level: message.level,
            outcome: outcome,
            text: shortened(message.text),
            callSite: callSite(file: message.file, line: message.line)
        )
    }

    private static func outcome(of message: LogMessage) -> EventOutcome? {
        if message.category == .issues {
            return message.level >= .fault ? .failed : .recovered
        }
        guard message.level == .debug, !message.text.contains("\n") else {
            return nil
        }
        return changeOutcome(verb: words(of: message.text).dropFirst(2).first ?? "")
    }

    private static func changeOutcome(verb: String) -> EventOutcome? {
        guard !skippedVerbs.contains(verb) else {
            return nil
        }
        return outcomesByVerb[verb] ?? .applied
    }

    // The line without the log's name and the padding that lines the columns up in a console.
    private static func shortened(_ text: String) -> String {
        text.split(separator: "\n")
            .map { words(of: String($0)).joined(separator: " ") }
            .joined(separator: "\n")
            .replacingOccurrences(of: "\(ReadableLogName.prefix) ", with: "")
    }

    private static func words(of line: String) -> [String] {
        line.split(separator: " ").map(String.init)
    }

    private static func callSite(file: StaticString, line: UInt) -> String {
        let path = "\(file)"
        let name = path.split(separator: "/").last.map(String.init) ?? path
        return "\(name):\(line)"
    }
}

// The name the readable log puts at the start of each line.
nonisolated enum ReadableLogName {
    static let prefix = "Waypoint"
}
