//
//  TrackedModel.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Observation

/// An observable model with one property a test reads and one it leaves untracked.
@Observable
final class TrackedModel {
    /// The property the tests track.
    ///
    /// `var` because the tests check that changing it is observed. Only ``rename(to:)`` changes it.
    private(set) var title = "Start"

    /// The property the tests change without reading it first.
    ///
    /// `var` because the tests check that changing it is not observed. Only ``increment()``
    /// changes it.
    private(set) var count = 0

    /// Changes the tracked property.
    func rename(to title: String) {
        self.title = title
    }

    /// Changes the untracked property.
    func increment() {
        count += 1
    }
}
