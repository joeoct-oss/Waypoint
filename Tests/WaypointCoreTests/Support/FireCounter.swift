//
//  FireCounter.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Foundation

/// Counts calls from a `@Sendable` closure, such as an observation `onChange` handler.
final class FireCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    /// The number of calls so far.
    var calls: Int {
        lock.withLock { value }
    }

    /// Records one call.
    func increment() {
        lock.withLock { value += 1 }
    }
}
