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
/// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
/// - `Equatable`, so tests and the router can compare values.
/// - `NavigationDescribable`, for a short, stable, private-by-default description in logs, events and test failures.
public enum NavigationOutcome: Sendable, Equatable, NavigationDescribable {
    /// The call did what it says.
    case applied
    /// The state already matched. Nothing changed and nothing is reported.
    case alreadyThere
    /// The call arrived while another change was being applied. It runs right after, in order.
    /// A failure is reported as an issue when it runs.
    case queued
    /// The router's flow is gone, so the call did nothing.
    case ignored
    /// The call failed. The state is unchanged.
    case failed(NavigationFailure)

    /// The failure, or `nil` for any other outcome.
    public var failure: NavigationFailure? {
        guard case .failed(let failure) = self else {
            return nil
        }
        return failure
    }

    /// `applied`, `alreadyThere`, `queued`, `ignored` or `failed <issue kind>`.
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
        case .failed(let failure):
            return "failed \(failure.issue.kind)"
        }
    }

    /// The line, and for a failure the failure's detailed form on the next lines.
    public func debugDescription(revealingPrivateValues: Bool) -> String {
        guard let failure else {
            return description
        }
        return "\(description)\n\(failure.debugDescription(revealingPrivateValues: revealingPrivateValues))"
    }
}
