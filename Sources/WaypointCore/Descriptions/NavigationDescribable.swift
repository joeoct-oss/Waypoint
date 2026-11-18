//
//  NavigationDescribable.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// A value with a short, stable, private-by-default description.
///
/// `description` is one line: a fixed first word, such as a case name, a route's type name or a
/// flow name, then `key=value` pairs. `debugDescription` starts with the same line and adds detail.
/// Route field values print as `<private>` unless the route lists them in
/// ``Route/publicLogFields``. Only ``debugDescription(revealingPrivateValues:)`` with `true`
/// shows them.
///
/// The format is part of the API: a change to it is listed in the changelog.
///
/// Conformances:
/// - `CustomStringConvertible`: `description` is the one-line form for logs and events.
/// - `CustomDebugStringConvertible`: `debugDescription` is the detailed form for debugging.
public protocol NavigationDescribable: CustomStringConvertible, CustomDebugStringConvertible {
    /// The detailed form, with route field values shown or redacted.
    func debugDescription(revealingPrivateValues: Bool) -> String
}

extension NavigationDescribable {
    /// Same as `debugDescription(revealingPrivateValues: false)`.
    public var debugDescription: String {
        debugDescription(revealingPrivateValues: false)
    }
}
