//
//  Once.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// Lets an observer act on its first call only, so a test can navigate from an observer without
/// looping.
@MainActor
package final class Once {
    /// Whether the first call was claimed.
    ///
    /// `var` because it turns on at the first call. Only ``claim()`` changes it.
    package private(set) var isClaimed = false

    /// Creates an unclaimed `Once`.
    package init() { }

    /// Returns `true` the first time it is called, and `false` after.
    package func claim() -> Bool {
        guard !isClaimed else {
            return false
        }
        isClaimed = true
        return true
    }
}
