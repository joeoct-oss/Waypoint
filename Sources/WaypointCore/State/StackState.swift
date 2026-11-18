//
//  StackState.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// The state of one navigation stack.
///
/// Conformances:
/// - `NavigationStateValue`, so it can be saved and restored, compared, sent off the main actor and described in logs.
public struct StackState: NavigationStateValue {
    /// The routes pushed above the stack's root screen, bottom first.
    ///
    /// The root screen belongs to the stack itself, not the path, as in
    /// `NavigationStack(path:)`. An empty path shows the root screen.
    public let path: [AnyRoute]

    /// The flow this stack presents, if any.
    public let presentation: Presentation?

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

    /// The same state with another path.
    func withPath(_ path: [AnyRoute]) -> StackState {
        StackState(path: path, presentation: presentation)
    }

    /// The same state with another presented flow.
    func withPresentation(_ presentation: Presentation?) -> StackState {
        StackState(path: path, presentation: presentation)
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
