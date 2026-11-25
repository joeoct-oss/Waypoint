//
//  AwaitedFlowResult.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// Awaiting a child flow's result: the `await` forms of `present` and `push` are built on the
/// `onFinish:` forms, so both give the same result in every ending path.
extension TreeNode {
    /// Starts a child flow with `start`, which gets the `onFinish:` to pass on and returns the
    /// start's outcome, and returns the flow's result once it ends.
    ///
    /// It returns `.cancelled` at once when `onFinish:` will never be called: the start was
    /// refused (`.failed`, `.alreadyThere`, `.ignored`), or Waypoint let the `onFinish:` go
    /// without calling it, as for a fallback that didn't start the child or a queued start that
    /// failed. Cancelling the awaiting task returns `.cancelled` at once and leaves the flow up;
    /// its result, when it ends, is logged at debug level as not delivered.
    func awaitResult<Output: Sendable>(
        of coordinator: Any.Type,
        file: StaticString,
        line: UInt,
        _ start: (@escaping @MainActor (FlowResult<Output>) -> Void) -> NavigationOutcome
    ) async -> FlowResult<Output> {
        let waiter = FlowResultWaiter<Output>(router: self, coordinator: coordinator, file: file, line: line)
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                waiter.wait(continuation)
                let delivery = FlowResultDelivery(waiter)
                let outcome = start { result in
                    delivery.deliver(result)
                }
                if outcome.neverFinishesAFlow {
                    waiter.end(.cancelled, by: .refusedStart)
                }
            }
        } onCancel: {
            Task { @MainActor in
                waiter.end(.cancelled, by: .cancelledTask)
            }
        }
    }
}

extension NavigationOutcome {
    /// Whether a start with this outcome never calls its `onFinish:`: it was refused, found its
    /// flow already there, or was ignored. `.applied` waits for the flow to end, and `.queued`
    /// and `.recovered` for Waypoint to call or let go of `onFinish:`.
    var neverFinishesAFlow: Bool {
        switch self {
        case .failed, .alreadyThere, .ignored:
            return true
        case .applied, .queued, .recovered:
            return false
        }
    }
}

/// The `onFinish:` an awaited start passes on. Waypoint keeps it while the flow may still end,
/// so when Waypoint lets it go without calling it, the flow never started and the awaiting call
/// returns `.cancelled`.
///
/// Conformances:
/// - `AnyObject`, so letting it go is seen in `deinit`.
@MainActor
private final class FlowResultDelivery<Output: Sendable> {
    /// The awaiting call it delivers to.
    private let waiter: FlowResultWaiter<Output>

    /// A delivery to `waiter`.
    init(_ waiter: FlowResultWaiter<Output>) {
        self.waiter = waiter
    }

    /// Returns `.cancelled` to the awaiting call, if nothing was delivered, once Waypoint lets
    /// `onFinish:` go. `deinit` can run on any thread, so it hops to the main actor.
    deinit {
        let waiter = waiter
        Task { @MainActor in
            waiter.end(.cancelled, by: .releasedStart)
        }
    }

    /// Delivers the flow's result.
    func deliver(_ result: FlowResult<Output>) {
        waiter.end(result, by: .flowEnded)
    }
}

/// One awaiting call to a child flow's result: it resumes once, with the first way it ends.
///
/// Conformances:
/// - `AnyObject`, because the delivery, the cancellation handler and the start share one.
@MainActor
private final class FlowResultWaiter<Output: Sendable> {
    /// How an awaiting call ended.
    enum Ending {
        /// The flow ended with its result.
        case flowEnded
        /// The start was refused, so the flow never started.
        case refusedStart
        /// Waypoint let `onFinish:` go without calling it, so the flow never started.
        case releasedStart
        /// The awaiting task was cancelled. The flow stays up.
        case cancelledTask
    }

    /// The router the flow was started on, which logs a result nobody waits for.
    private weak var router: (any TreeNode)?

    /// The child coordinator's type, named in the log.
    private let coordinator: Any.Type

    /// The calling file, where the log line points.
    private let file: StaticString

    /// The calling line, where the log line points.
    private let line: UInt

    /// The suspended call, until it resumes.
    ///
    /// `var` because the call suspends after the waiter is made and resumes once. Only `wait(_:)`
    /// and `end(_:by:)` change it.
    private var continuation: CheckedContinuation<FlowResult<Output>, Never>?

    /// How the call ended, or `nil` while it waits.
    ///
    /// `var` because the call ends once. Only `end(_:by:)` changes it.
    private var ending: Ending?

    /// A waiter for a flow of `coordinator` started on `router` at `file` and `line`.
    init(router: any TreeNode, coordinator: Any.Type, file: StaticString, line: UInt) {
        self.router = router
        self.coordinator = coordinator
        self.file = file
        self.line = line
    }

    /// Keeps the suspended call until it ends.
    func wait(_ continuation: CheckedContinuation<FlowResult<Output>, Never>) {
        self.continuation = continuation
    }

    /// Resumes the call with `result` the first time. A flow that ends after its task was
    /// cancelled is logged as not delivered; anything else later is dropped.
    func end(_ result: FlowResult<Output>, by ending: Ending) {
        guard let continuation else {
            logIfNotDelivered(result, ending: ending)
            return
        }
        self.continuation = nil
        self.ending = ending
        continuation.resume(returning: result)
    }

    /// Logs `result` at debug level when the flow ended after the awaiting task was cancelled.
    private func logIfNotDelivered(_ result: FlowResult<Output>, ending: Ending) {
        guard self.ending == .cancelledTask, ending == .flowEnded, let router else {
            return
        }
        let name = ViewTypeName.of(coordinator)
        let kind = Self.kind(of: result)
        let flow = router.flowID
        router.tree.log(.debug, .flows, file: file, line: line) { _ in
            "result not delivered flow=\(flow) coordinator=\(name) result=\(kind): the task "
                + "awaiting it was cancelled. Await a flow from a coordinator or a task the app "
                + "keeps, or use onFinish: from a screen."
        }
    }

    /// `finished` or `cancelled`, without the value, which may be private.
    private static func kind(of result: FlowResult<Output>) -> String {
        switch result {
        case .finished:
            return "finished"
        case .cancelled:
            return "cancelled"
        }
    }
}
