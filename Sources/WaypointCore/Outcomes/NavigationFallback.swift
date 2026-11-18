//
//  NavigationFallback.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// What to do when a call fails.
///
/// A fallback is chosen in this order: the call's own `else:` argument, then the router's
/// ``FallbackPolicy`` (children inherit it), then the built-in default for that kind of issue.
/// The built-in defaults change nothing unless the intent is clear: popping more routes than the
/// path holds pops to root, and every other kind defaults to `.none`.
///
/// A fallback runs once, inside the same change as the call, and never triggers another
/// fallback. If it fails too, the call is rolled back and reported as a ``NavigationFailure``.
///
/// Two `custom` fallbacks are equal when their names are equal. The name also appears in logs
/// and outcomes.
///
/// Conformances:
/// - `NavigationRecord`, so it can be sent off the main actor, compared in tests and described in
///   logs.
public enum NavigationFallback: NavigationRecord {
    /// Do nothing. The outcome is `.failed`.
    case none
    /// Pop the stack to its root screen. On a tab container, pops the selected tab's stack.
    case popToRoot
    /// For `popTo` a route value: push it instead.
    case push
    /// Dismiss everything presented over this flow.
    case dismissAll
    /// Dismiss everything and pop the root router's stack to its root screen.
    case resetToRoot
    /// For `present` while a flow is already presented: dismiss that flow and everything above
    /// it, then present the new route with the call's style, in one change.
    ///
    /// Use it where newer intent wins, such as a notification tap while a sheet is open. A
    /// replacement made in code doesn't ask the presented flow for a leave confirmation; that
    /// only applies to the user's own gestures. On any other call it fails with `fallbackFailed`.
    case replacePresentation
    /// Run your own change. The name appears in logs and outcomes.
    case custom(_ name: String, @MainActor @Sendable (NavigationTransaction, NavigationIssue) -> Void)

    /// The case name, or `custom(name)`.
    public var description: String {
        switch self {
        case .none:
            return "none"
        case .popToRoot:
            return "popToRoot"
        case .push:
            return "push"
        case .dismissAll:
            return "dismissAll"
        case .resetToRoot:
            return "resetToRoot"
        case .replacePresentation:
            return "replacePresentation"
        case .custom(let name, _):
            return "custom(\(name))"
        }
    }

    /// The built-in default for an issue kind: `.popToRoot` for `notEnoughRoutes`, `.none` for
    /// every other kind.
    public static func builtIn(for kind: NavigationIssue.Kind) -> NavigationFallback {
        kind == .notEnoughRoutes ? .popToRoot : .none
    }

    /// Whether two fallbacks are the same case, comparing `custom` fallbacks by name.
    public static func == (lhs: NavigationFallback, rhs: NavigationFallback) -> Bool {
        lhs.description == rhs.description
    }

    /// The same line. A fallback holds no private values.
    public func debugDescription(revealingPrivateValues: Bool) -> String {
        description
    }
}

/// Fallbacks by issue kind, inherited by child routers.
///
/// ```swift
/// router.setFallback(.popToRoot, for: .routeNotInPath)   // for this flow and its children
/// ```
///
/// Conformances:
/// - `Sendable`, so the configuration can be built anywhere and shared with the whole tree.
public struct FallbackPolicy: Sendable {
    /// Fallbacks set for each kind.
    private let fallbacks: [NavigationIssue.Kind: NavigationFallback]

    /// Creates an empty policy: every kind uses its parent's entry, then the built-in default.
    public init() {
        self.fallbacks = [:]
    }

    /// A policy with these fallbacks.
    private init(fallbacks: [NavigationIssue.Kind: NavigationFallback]) {
        self.fallbacks = fallbacks
    }

    /// The fallback set for a kind, or `nil` to use the parent's entry, then the built-in default.
    public subscript(kind: NavigationIssue.Kind) -> NavigationFallback? {
        fallbacks[kind]
    }

    /// The same policy with a fallback set for one kind, or cleared with `nil`.
    public func withFallback(_ fallback: NavigationFallback?, for kind: NavigationIssue.Kind) -> FallbackPolicy {
        let others = fallbacks.filter { $0.key != kind }
        guard let fallback else {
            return FallbackPolicy(fallbacks: others)
        }
        let added = [kind: fallback]
        return FallbackPolicy(fallbacks: others.merging(added) { _, new in new })
    }
}
