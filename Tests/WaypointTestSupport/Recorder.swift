//
//  Recorder.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// Keeps the values an observer or handler was called with, so a test can check them after.
///
/// Tests use it instead of a captured `var`, so the only mutable state is here, with a reason.
@MainActor
package final class Recorder<Value> {
    /// The recorded values, oldest first.
    ///
    /// `var` because observers call in one at a time. Only ``record(_:)`` and
    /// ``record(contentsOf:)`` change it.
    package private(set) var values: [Value] = []

    /// The number of values recorded so far.
    package var count: Int {
        values.count
    }

    /// The most recent value, or `nil` before the first.
    package var last: Value? {
        values.last
    }

    /// Creates an empty recorder.
    package init() { }

    /// Records one value.
    package func record(_ value: Value) {
        values.append(value)
    }

    /// Records several values, in order.
    package func record(contentsOf newValues: [Value]) {
        values.append(contentsOf: newValues)
    }
}
