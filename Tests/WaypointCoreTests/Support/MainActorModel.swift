//
//  MainActorModel.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// A main-actor model that a `@MainActor` test calls synchronously.
@MainActor
final class MainActorModel {
    /// The pushed screen names, oldest first.
    private(set) var stack: [String] = []

    /// Pushes a screen name onto the stack.
    func push(_ name: String) {
        stack.append(name)
    }
}
