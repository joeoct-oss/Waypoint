//
//  TransactionStore.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// A router that a transaction can change on a working copy, then commit or roll back.
///
/// Conformances:
/// - `AnyObject`, because the store keeps each router once, by identity.
@MainActor
protocol TransactionParticipant: AnyObject {
    /// Copies the committed state into a working copy.
    func beginWorkingCopy()

    /// Writes the working copy back as the state, once.
    func commitWorkingCopy()

    /// Drops the working copy.
    func discardWorkingCopy()
}

/// Who asked for a change. The public form arrives with events (#23).
///
/// Conformances:
/// - `Sendable`, so changes can be handed to observers off the main actor later.
/// - `Equatable`, so tests can compare them.
enum ChangeOrigin: Sendable, Equatable {
    /// App code called a router.
    case app
    /// A fallback ran because the call that was asked for failed.
    case fallback

    /// The user changed the screen directly, such as a swipe back, and the renderer reported it.
    case user
}

/// One change, with the flow it happened in and who asked for it.
///
/// Conformances:
/// - `Sendable`, so changes can be handed to observers off the main actor later.
/// - `Equatable`, so tests can compare them.
struct AppliedChange: Sendable, Equatable {
    /// The flow that changed.
    let flow: FlowID

    /// What changed.
    let change: NavigationChange

    /// Who asked for it.
    let origin: ChangeOrigin

    /// A change in a flow. App code asked for it unless `origin` says otherwise.
    init(flow: FlowID, change: NavigationChange, origin: ChangeOrigin = .app) {
        self.flow = flow
        self.change = change
        self.origin = origin
    }
}

/// What one step did to the working copies, before any fallback.
enum StepResult {
    /// The working copy changed.
    case changed
    /// Nothing needed to change.
    case unchanged
    /// The step was refused, and changed nothing.
    case failed(IssueDraft)
}

/// What a call or a transaction did, after fallbacks.
enum CallResult {
    /// The working copies changed.
    case changed
    /// Nothing needed to change.
    case unchanged
    /// The call failed and its fallback succeeded.
    case recovered(NavigationIssue, NavigationFallback)
    /// The call failed and no fallback succeeded. Everything rolls back.
    case failed(NavigationFailure)
}

/// An issue before the call site is attached.
struct IssueDraft {
    /// What went wrong.
    let kind: NavigationIssue.Kind

    /// The flow the call was made on.
    let flow: FlowID

    /// Builds what went wrong and how to fix it, naming routes the way the reader needs.
    let describeMessage: @Sendable (RouteNaming) -> String

    /// A draft whose message names no routes.
    init(kind: NavigationIssue.Kind, flow: FlowID, message: String) {
        self.init(kind: kind, flow: flow) { _ in
            message
        }
    }

    /// A draft whose message names routes.
    init(
        kind: NavigationIssue.Kind,
        flow: FlowID,
        describeMessage: @escaping @Sendable (RouteNaming) -> String
    ) {
        self.kind = kind
        self.flow = flow
        self.describeMessage = describeMessage
    }

    /// The issue with the call's file and line.
    func issue(file: StaticString, line: UInt) -> NavigationIssue {
        NavigationIssue(kind: kind, flow: flow, file: file, line: line, describeMessage: describeMessage)
    }
}

/// The working copies, changes and issues of one transaction.
@MainActor
final class TransactionStore {
    /// Every router changed so far, in the order it was first changed. `var` because routers
    /// join as steps change them, through ``enlist(_:)``.
    private var participants: [any TransactionParticipant] = []

    /// The routers already in `participants`. `var` because routers join as steps change them,
    /// through ``enlist(_:)``.
    private var enlisted: Set<ObjectIdentifier> = []

    /// The changes so far, in order. `var` because each step adds its changes, through
    /// ``record(_:in:)``.
    private(set) var changes: [AppliedChange] = []

    /// Issues to report when the transaction ends, in order, with the level to log them at:
    /// `.error` for a recovered call, `.fault` for a failed one. `var` because steps add them,
    /// through ``keep(_:level:)``.
    private(set) var issues: [(issue: NavigationIssue, level: LogLevel)] = []

    /// The first failed step of a transaction, if any. Later steps are skipped. `var` because a
    /// step can fail, through ``note(_:)``, and a custom fallback runs with it set aside, through
    /// ``isolatingFailure(_:)``.
    private(set) var failure: NavigationFailure?

    /// The first recovered step of a transaction, if any. `var` because a step can recover,
    /// through ``note(_:)``.
    private var recovery: (issue: NavigationIssue, fallback: NavigationFallback)?

    /// Whether any step of a transaction changed something. `var` because steps change things,
    /// through ``note(_:)``.
    private var hasChanged = false

    /// Who the changes being recorded now come from. `var` because a fallback's changes are
    /// marked as its own, through ``asFallback(_:)``.
    private(set) var origin = ChangeOrigin.app

    /// The route of a push skipped because the same route was still being pushed, if any.
    /// `var` because a push step can skip, through ``noteSkippedPush(_:)``.
    private(set) var skippedPush: AnyRoute?

    /// What the whole transaction did, from its steps.
    var transactionResult: CallResult {
        if let failure {
            return .failed(failure)
        }
        if let recovery {
            return .recovered(recovery.issue, recovery.fallback)
        }
        return hasChanged ? .changed : .unchanged
    }

    /// Makes a working copy of the router, once per transaction.
    func enlist(_ participant: some TransactionParticipant) {
        guard enlisted.insert(ObjectIdentifier(participant)).inserted else {
            return
        }
        participants.append(participant)
        participant.beginWorkingCopy()
    }

    /// Records changes made in one flow, with the current origin.
    func record(_ changes: [NavigationChange], in flow: FlowID) {
        self.changes.append(contentsOf: changes.map { AppliedChange(flow: flow, change: $0, origin: origin) })
    }

    /// Records a push skipped by the duplicate push rule, so the log can say why nothing changed.
    func noteSkippedPush(_ route: AnyRoute) {
        skippedPush = route
    }

    /// Keeps an issue to report when the transaction ends.
    func keep(_ issue: NavigationIssue, level: LogLevel) {
        issues.append((issue, level))
    }

    /// Records what one step of a transaction did, and returns it as the step's outcome.
    func note(_ result: CallResult) -> NavigationOutcome {
        switch result {
        case .changed:
            return noteChanged()
        case .unchanged:
            return .alreadyThere
        case .recovered(let issue, let fallback):
            return noteRecovered(issue, fallback)
        case .failed(let failure):
            return noteFailure(failure)
        }
    }

    /// Runs `body` with its changes marked as coming from a fallback.
    func asFallback<Result>(_ body: () -> Result) -> Result {
        marked(.fallback, body)
    }

    /// Runs `body` with its changes marked as coming from the user, through a renderer report.
    func asUser<Result>(_ body: () -> Result) -> Result {
        marked(.user, body)
    }

    /// Runs `body` with no earlier failure, and returns the issue of its first failed step, if
    /// any. The earlier failure is restored afterwards.
    func isolatingFailure(_ body: () -> Void) -> NavigationIssue? {
        let earlier = failure
        failure = nil
        body()
        let issue = failure?.issue
        failure = earlier
        return issue
    }

    /// Writes every working copy back.
    func commit() {
        for participant in participants {
            participant.commitWorkingCopy()
        }
    }

    /// Drops every working copy.
    func rollback() {
        for participant in participants {
            participant.discardWorkingCopy()
        }
    }

    /// Runs `body` with its changes marked with `marking`, then restores the origin before it.
    private func marked<Result>(_ marking: ChangeOrigin, _ body: () -> Result) -> Result {
        let previous = origin
        origin = marking
        defer {
            origin = previous
        }
        return body()
    }

    /// Marks the transaction as changed.
    private func noteChanged() -> NavigationOutcome {
        hasChanged = true
        return .applied
    }

    /// Keeps the first recovery. A recovery changed the state, or kept it as the fallback wants.
    private func noteRecovered(_ issue: NavigationIssue, _ fallback: NavigationFallback) -> NavigationOutcome {
        hasChanged = true
        if recovery == nil {
            recovery = (issue, fallback)
        }
        return .recovered(issue, by: fallback)
    }

    /// Keeps the first failure. The transaction rolls back when it ends.
    private func noteFailure(_ failure: NavigationFailure) -> NavigationOutcome {
        if self.failure == nil {
            self.failure = failure
        }
        return .failed(failure)
    }
}
