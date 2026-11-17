//
//  TransactionStore.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
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

/// One change, with the flow it happened in.
///
/// Conformances:
/// - `Sendable`, so changes can be handed to observers off the main actor later.
/// - `Equatable`, so tests can compare them.
struct AppliedChange: Sendable, Equatable {
    /// The flow that changed.
    let flow: FlowID

    /// What changed.
    let change: NavigationChange
}

/// What one step of a transaction did.
enum StepResult {
    /// The working copy changed.
    case changed
    /// Nothing needed to change.
    case unchanged
    /// The step was refused. The transaction rolls back.
    case failed(IssueDraft)
    /// A step inside a transaction was refused at its own call site. The transaction rolls back.
    case failedAt(NavigationIssue)
}

/// An issue before the call site is attached.
struct IssueDraft {
    /// What went wrong.
    let kind: NavigationIssue.Kind

    /// The flow the call was made on.
    let flow: FlowID

    /// What went wrong and how to fix it.
    let message: String

    /// The issue with the call's file and line.
    func issue(file: StaticString, line: UInt) -> NavigationIssue {
        NavigationIssue(kind: kind, flow: flow, message: message, file: file, line: line)
    }
}

/// The working copies and changes of one transaction.
@MainActor
final class TransactionStore {
    /// Every router changed so far, in the order it was first changed.
    private var participants: [any TransactionParticipant] = []

    /// The routers already in `participants`.
    private var enlisted: Set<ObjectIdentifier> = []

    /// The changes so far, in order.
    private(set) var changes: [AppliedChange] = []

    /// The first failed step of a transaction, if any. Later steps are skipped.
    private(set) var failure: NavigationIssue?

    /// Whether any step of a transaction changed something.
    private(set) var hasChanged = false

    /// What the whole transaction did, from its steps.
    var transactionResult: StepResult {
        if let failure {
            return .failedAt(failure)
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

    /// Records changes made in one flow.
    func record(_ changes: [NavigationChange], in flow: FlowID) {
        self.changes.append(contentsOf: changes.map { AppliedChange(flow: flow, change: $0) })
    }

    /// Records what one step of a transaction did, and returns it as an outcome.
    func note(_ result: StepResult, file: StaticString, line: UInt) -> NavigationOutcome {
        switch result {
        case .changed:
            return noteChanged()
        case .unchanged:
            return .alreadyThere
        case .failed(let draft):
            return noteFailure(draft.issue(file: file, line: line))
        case .failedAt(let issue):
            return noteFailure(issue)
        }
    }

    /// Marks the transaction as changed.
    private func noteChanged() -> NavigationOutcome {
        hasChanged = true
        return .applied
    }

    /// Keeps the first failure. The transaction rolls back when it ends.
    func noteFailure(_ issue: NavigationIssue) -> NavigationOutcome {
        if failure == nil {
            failure = issue
        }
        return .failed(NavigationFailure(issue: failure ?? issue))
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
}
