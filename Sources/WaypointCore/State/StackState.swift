//
//  StackState.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// The state of one navigation stack.
///
/// Conformances:
/// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
/// - `Equatable`, so tests and the router can compare values.
/// - `Codable`, so it can be saved, restored and logged.
/// - `NavigationDescribable`, for a short, stable, private-by-default description in logs, events and test failures.
public struct StackState: Sendable, Equatable, Codable, NavigationDescribable {
    /// The routes pushed above the stack's root screen, bottom first.
    ///
    /// The root screen belongs to the stack itself, not the path, as in
    /// `NavigationStack(path:)`. An empty path shows the root screen.
    public var path: [AnyRoute]

    /// The flow this stack presents, if any.
    public var presentation: Presentation?

    /// The path, such as `[HomeRoute, ProductRoute(id: <private>)]`, then `+` and the
    /// presentation if there is one.
    public var description: String {
        debugDescription(revealingPrivateValues: false)
    }

    /// Creates a stack state. Both values default to empty.
    public init(path: [AnyRoute] = [], presentation: Presentation? = nil) {
        self.path = path
        self.presentation = presentation
    }

    /// The same line, with route fields revealed when asked.
    public func debugDescription(revealingPrivateValues: Bool) -> String {
        let path = DescriptionFormat.list(path, revealingPrivateValues: revealingPrivateValues)
        guard let presentation else {
            return path
        }
        return "\(path) + \(presentation.debugDescription(revealingPrivateValues: revealingPrivateValues))"
    }
}
