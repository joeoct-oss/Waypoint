//
//  PresentationReducer.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// A state that can present one flow: a stack or a tab container.
protocol PresentingState: Equatable {
    /// The presented flow, if any.
    var presentation: Presentation? { get }

    /// The same state with another presented flow.
    func withPresentation(_ presentation: Presentation?) -> Self
}

/// Conformances:
/// - `PresentingState`, so a stack can present a flow.
extension StackState: PresentingState { }

/// Conformances:
/// - `PresentingState`, so a tab container can present a flow above all its tabs.
extension TabState: PresentingState { }

/// A change to what a flow presents.
///
/// Conformances:
/// - `Sendable`, so commands can be queued and logged.
/// - `Equatable`, so tests can compare commands.
enum PresentationCommand: Sendable, Equatable {
    /// Present a flow.
    case present(Presentation)
    /// Dismiss the presented flow.
    case dismiss
}

/// Applies presentation commands. Pure: no routers, no globals.
enum PresentationReducer {
    /// Applies one command. A flow presents at most one flow at a time.
    static func reduce<State: PresentingState>(_ state: State, _ command: PresentationCommand) -> Reduction<State> {
        switch command {
        case .present(let presentation):
            return present(presentation, on: state)
        case .dismiss:
            return dismiss(state)
        }
    }

    /// Sets the presentation, unless one is already shown.
    private static func present<State: PresentingState>(
        _ presentation: Presentation,
        on state: State
    ) -> Reduction<State> {
        if let current = state.presentation {
            return .rejected(.alreadyPresenting(current.flow))
        }
        let changes: [NavigationChange] = [.presented(presentation)]
        return .changed(state.withPresentation(presentation), changes)
    }

    /// Clears the presentation.
    private static func dismiss<State: PresentingState>(_ state: State) -> Reduction<State> {
        guard let current = state.presentation else {
            return .unchanged
        }
        let changes: [NavigationChange] = [.dismissed(current.flow)]
        return .changed(state.withPresentation(nil), changes)
    }
}
