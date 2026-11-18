//
//  RouterSettings.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// The settings an app can change on one router after creating it.
///
/// Conformances:
/// - `Sendable`, so settings can be built anywhere.
struct RouterSettings: Sendable {
    /// Presentation defaults set on this router, or `nil` to inherit them.
    let presentationDefaults: PresentationDefaults?

    /// This router's own fallbacks by issue kind.
    let fallbackPolicy: FallbackPolicy

    /// Settings with nothing set: defaults and fallbacks are inherited.
    init(presentationDefaults: PresentationDefaults? = nil, fallbackPolicy: FallbackPolicy = FallbackPolicy()) {
        self.presentationDefaults = presentationDefaults
        self.fallbackPolicy = fallbackPolicy
    }

    /// The same settings with presentation defaults set.
    func withPresentationDefaults(_ defaults: PresentationDefaults) -> RouterSettings {
        RouterSettings(presentationDefaults: defaults, fallbackPolicy: fallbackPolicy)
    }

    /// The same settings with one fallback set, or cleared with `nil`.
    func withFallback(_ fallback: NavigationFallback?, for kind: NavigationIssue.Kind) -> RouterSettings {
        RouterSettings(
            presentationDefaults: presentationDefaults,
            fallbackPolicy: fallbackPolicy.withFallback(fallback, for: kind)
        )
    }
}

extension TreeNode {
    /// Why a fallback can't be set for a kind, or `nil` when it can.
    ///
    /// `.push` only works after `popTo` with a route value, which fails with `routeNotInPath`.
    func fallbackSettingProblem(_ fallback: NavigationFallback?, for kind: NavigationIssue.Kind) -> String? {
        guard fallback == .push, kind != .routeNotInPath else {
            return nil
        }
        return "The .push fallback only applies to routeNotInPath, after popTo with a route value, "
            + "so it was not set for \(kind). The fallback for \(kind) is unchanged."
    }

    /// Reports a setting that was refused, and keeps the old value.
    func reportInvalidSetting(_ message: String, file: StaticString, line: UInt) {
        let issue = NavigationIssue(kind: .invalidSetting, flow: flowID, message: message, file: file, line: line)
        tree.report(issue, level: .fault)
    }
}
