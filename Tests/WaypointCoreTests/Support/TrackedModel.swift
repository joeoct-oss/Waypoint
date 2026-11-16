//
//  TrackedModel.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Observation

/// An observable model with one property a test reads and one it leaves untracked.
@Observable
final class TrackedModel {
    /// The property the tests track.
    var title = "Start"
    /// The property the tests change without reading it first.
    var count = 0
}
