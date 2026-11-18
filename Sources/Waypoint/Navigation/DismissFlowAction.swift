//
//  DismissFlowAction.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// Not guarded by `canImport(SwiftUI)`: it uses only the core, so it is unit tested on Linux too.
// The `@DismissFlow` property wrapper that makes it is in `DismissFlow.swift`.

import WaypointCore

/// Dismisses the flow a view is in. Call it like a function.
///
/// `@DismissFlow` gives one. Like SwiftUI's `DismissAction`, the value is an action:
///
/// ```swift
/// struct SettingsView: View {
///     @DismissFlow private var dismissFlow
///
///     var body: some View {
///         Button("Close") { dismissFlow() }
///     }
/// }
/// ```
///
/// It asks whoever presented the flow to dismiss it, with everything the flow presents. In a
/// flow that wasn't presented, such as the app's first stack, it fails with `notPresented`.
@MainActor
public struct DismissFlowAction {
    /// The navigator of the stack the view is in.
    private let navigator: StackNavigator

    /// Whether the flow is still in the tree. When it isn't, a call returns `.ignored`.
    public var isActive: Bool {
        navigator.isActive
    }

    /// An action that dismisses `navigator`'s flow.
    init(navigator: StackNavigator) {
        self.navigator = navigator
    }

    /// Dismisses the flow. See `StackNavigator.dismissFlow(else:file:line:)`.
    @discardableResult
    public func callAsFunction(
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> NavigationOutcome {
        navigator.dismissFlow(else: fallback, file: file, line: line)
    }
}
