//
//  FireCounter.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Foundation

/// Counts calls from a `@Sendable` closure, such as an observation `onChange` handler.
///
/// Conformances:
/// - `@unchecked Sendable`, because the count is shared with closures that can run on any
///   thread, and every access goes through `lock`, which the compiler can't check.
final class FireCounter: @unchecked Sendable {
    /// Guards `value`, because the closures that call `increment()` can run on any thread.
    private let lock = NSLock()
    /// The count, read and written only under `lock`.
    ///
    /// `var` because each call adds one. Only ``increment()`` changes it.
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
