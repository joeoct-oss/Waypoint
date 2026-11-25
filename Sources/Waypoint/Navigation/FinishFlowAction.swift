//
//  FinishFlowAction.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// Not guarded by `canImport(SwiftUI)`: it uses only the core, so it is unit tested on Linux too.
// The `@FinishFlow` property wrapper that makes it is in `FinishFlow.swift`.

import WaypointCore

/// Ends the child flow a view is in with a value. Call it like a function.
///
/// `@FinishFlow(ReviewCoordinator.self)` gives one, for the flow of `ReviewCoordinator`, whose
/// `Output` is the only value it takes:
///
/// ```swift
/// struct ReviewView: View {
///     @FinishFlow(ReviewCoordinator.self) private var finishFlow
///     let review: Review
///
///     var body: some View {
///         Button("Post") { finishFlow(review) }
///     }
/// }
/// ```
///
/// It does what the coordinator's `finish(with:)` does: the parent gets `.finished(output)`, in
/// its `onFinish:` or its `await`, and the flow is dismissed, or popped when it was pushed. It
/// finds the nearest flow of its coordinator's type above the view, however deep the view is in
/// it, such as in a sheet the flow presented. Outside that flow it changes nothing: it fails
/// with `noRouterInScope`, naming the coordinator and where the wrapper is declared, and nothing
/// crashes.
@MainActor
public struct FinishFlowAction<Output: Sendable> {
    /// The router of the stack the view is in, or `nil` outside one.
    private let router: StackRouter?

    /// The coordinator type of the flow it finishes.
    private let coordinator: Any.Type

    /// The wrapper and the site of its declaration, named in an issue.
    private let wrapper: String

    /// Fails a call when no stack is above the view.
    private let missing: StackNavigator

    /// Whether the view is in a running flow of the coordinator's type. When it isn't, a call
    /// changes nothing.
    public var isActive: Bool {
        router?.isInFlow(of: coordinator) ?? false
    }

    /// An action that finishes the flow of `coordinator` above `router`'s stack. `wrapper` names
    /// the declaration in an issue, and `missing` fails a call when there is no stack.
    init(router: StackRouter?, coordinator: Any.Type, wrapper: String, missing: StackNavigator) {
        self.router = router
        self.coordinator = coordinator
        self.wrapper = wrapper
        self.missing = missing
    }

    /// Ends the flow with `output`.
    ///
    /// - Parameters:
    ///   - output: The value the flow ends with.
    ///   - file: The calling file, where an issue points. Leave the default.
    ///   - line: The calling line, where an issue points. Leave the default.
    /// - Returns: The outcome of dismissing the flow, `.failed` with `noRouterInScope` outside
    ///   it, or `.ignored` once the flow has ended.
    @discardableResult
    public func callAsFunction(
        _ output: Output,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> NavigationOutcome {
        guard let router else {
            return missing.dismissFlow(file: file, line: line)
        }
        return router.finishFlow(of: coordinator, with: output, wrapper: wrapper, file: file, line: line)
    }
}
