//
//  NavigationOutcome.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// What a navigation call did.
///
/// Every navigation method returns one. The result is discardable, so most code ignores it, and
/// code that needs to know can check it:
///
/// ```swift
/// if case .failed = router.popTo(CheckoutRoute()) {
///     showCheckoutExpired()
/// }
/// ```
///
/// Conformances:
/// - `NavigationRecord`, so it can be sent off the main actor, compared in tests and described in logs.
public enum NavigationOutcome: NavigationRecord {
    /// The call did what it says.
    case applied
    /// The state already matched. Nothing changed and nothing is reported.
    case alreadyThere
    /// The call arrived while another change was being applied. It runs right after, in order.
    /// A failure is reported as an issue when it runs.
    case queued
    /// The router's flow is gone, so the call did nothing.
    case ignored
    /// The call failed, and its fallback succeeded.
    case recovered(NavigationIssue, by: NavigationFallback)
    /// The call failed and no fallback succeeded. The state is unchanged.
    case failed(NavigationFailure)

    /// The failure, or `nil` for any other outcome.
    public var failure: NavigationFailure? {
        guard case .failed(let failure) = self else {
            return nil
        }
        return failure
    }

    /// `applied`, `alreadyThere`, `queued`, `ignored`, `recovered <issue kind> by=<fallback>` or
    /// `failed <issue kind>`.
    public var description: String {
        switch self {
        case .applied:
            return "applied"
        case .alreadyThere:
            return "alreadyThere"
        case .queued:
            return "queued"
        case .ignored:
            return "ignored"
        case .recovered(let issue, let fallback):
            return "recovered \(issue.kind) by=\(fallback)"
        case .failed(let failure):
            return "failed \(failure.issue.kind)"
        }
    }

    /// The issue that was recovered from, or `nil` for any other outcome.
    public var recoveredIssue: NavigationIssue? {
        guard case .recovered(let issue, _) = self else {
            return nil
        }
        return issue
    }

    /// The line, and for a failure or a recovery the detailed form of what went wrong.
    public func debugDescription(revealingPrivateValues: Bool) -> String {
        if let failure {
            return "\(description)\n\(failure.debugDescription(revealingPrivateValues: revealingPrivateValues))"
        }
        if let recoveredIssue {
            return "\(description)\n\(recoveredIssue.debugDescription(revealingPrivateValues: revealingPrivateValues))"
        }
        return description
    }
}
