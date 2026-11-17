//
//  NavigationFailure.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// A call that failed, with the issue that stopped it and, when a fallback ran and failed too,
/// the fallback and its issue.
///
/// Conformances:
/// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
/// - `Equatable`, so tests and the router can compare values.
/// - `NavigationDescribable`, for a short, stable, private-by-default description in logs, events and test failures.
public struct NavigationFailure: Sendable, Equatable, NavigationDescribable {
    /// Why the call failed.
    public let issue: NavigationIssue

    /// The fallback that ran and failed, or `nil` when no fallback ran.
    public let fallback: NavigationFallback?

    /// Why the call's fallback failed too, or `nil` when no fallback ran.
    public let fallbackIssue: NavigationIssue?

    /// `failed routeNotInPath flow=shop at=ShopCoordinator.swift:42`, with
    /// `fallback=popToRoot fallbackIssue=emptyPath` when a fallback failed too.
    public var description: String {
        guard let fallback, let fallbackIssue else {
            return "failed \(issue)"
        }
        return "failed \(issue) fallback=\(fallback) fallbackIssue=\(fallbackIssue.kind)"
    }

    /// Describes a failure.
    public init(issue: NavigationIssue, fallback: NavigationFallback? = nil, fallbackIssue: NavigationIssue? = nil) {
        self.issue = issue
        self.fallback = fallback
        self.fallbackIssue = fallbackIssue
    }

    /// The line, then each issue's message.
    public func debugDescription(revealingPrivateValues: Bool) -> String {
        let messages = [issue.message] + (fallbackIssue.map { [$0.message] } ?? [])
        return ([description] + messages.map { "  \($0)" }).joined(separator: "\n")
    }
}
