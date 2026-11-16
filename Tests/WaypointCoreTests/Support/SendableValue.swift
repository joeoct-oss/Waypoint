//
//  SendableValue.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// A plain value type that crosses actor boundaries in Swift 6 mode.
struct SendableValue: Sendable, Equatable {
    /// An identifier.
    let id: Int
    /// A display name.
    let name: String
}
