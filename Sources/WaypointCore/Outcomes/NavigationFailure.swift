//
//  NavigationFailure.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// A call that failed, with the issue that stopped it.
///
/// Conformances:
/// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
/// - `Equatable`, so tests and the router can compare values.
/// - `NavigationDescribable`, for a short, stable, private-by-default description in logs, events and test failures.
public struct NavigationFailure: Sendable, Equatable, NavigationDescribable {
    /// Why the call failed.
    public let issue: NavigationIssue

    /// Why the call's fallback failed too, or `nil` when no fallback ran.
    public let fallbackIssue: NavigationIssue?

    /// Describes a failure.
    public init(issue: NavigationIssue, fallbackIssue: NavigationIssue? = nil) {
        self.issue = issue
        self.fallbackIssue = fallbackIssue
    }

    /// `failed routeNotInPath flow=shop at=ShopCoordinator.swift:42`, with
    /// `fallbackIssue=<kind>` when a fallback failed too.
    public var description: String {
        guard let fallbackIssue else {
            return "failed \(issue)"
        }
        return "failed \(issue) fallbackIssue=\(fallbackIssue.kind)"
    }

    /// The line, then each issue's message.
    public func debugDescription(revealingPrivateValues: Bool) -> String {
        let messages = [issue.message] + (fallbackIssue.map { [$0.message] } ?? [])
        return ([description] + messages.map { "  \($0)" }).joined(separator: "\n")
    }
}
