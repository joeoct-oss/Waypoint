//
//  NavigationTreeContext+Values.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

extension NavigationTreeContext {
    /// How the tree logs, and how many calls may be queued in one turn.
    struct Settings {
        /// How the tree logs.
        let logging: LogConfiguration

        /// The most calls that may be queued in one main-actor turn.
        let maxQueuedChanges: Int

        /// The defaults: ``LogConfiguration/default`` and 32 queued calls.
        init(logging: LogConfiguration = .default, maxQueuedChanges: Int = 32) {
            self.logging = logging
            self.maxQueuedChanges = maxQueuedChanges
        }

        /// The same settings, logging another way.
        func withLogging(_ logging: LogConfiguration) -> Settings {
            Settings(logging: logging, maxQueuedChanges: maxQueuedChanges)
        }

        /// The same settings with another queue limit.
        func withMaxQueuedChanges(_ limit: Int) -> Settings {
            Settings(logging: logging, maxQueuedChanges: limit)
        }
    }

    /// The seams for observers, logging, strict mode and the app's failure handlers.
    struct Observers {
        /// Called with the changes of each committed transaction.
        let applied: (([AppliedChange]) -> Void)?

        /// Called with each issue when it is reported.
        let reported: ((NavigationIssue) -> Void)?

        /// Called with the outcome of every call.
        let finished: ((NavigationOutcome) -> Void)?

        /// The app's handlers for calls that failed and could not be recovered.
        let failureHandlers: [(NavigationFailure) -> Void]

        /// No observers.
        init(
            applied: (([AppliedChange]) -> Void)? = nil,
            reported: ((NavigationIssue) -> Void)? = nil,
            finished: ((NavigationOutcome) -> Void)? = nil,
            failureHandlers: [(NavigationFailure) -> Void] = []
        ) {
            self.applied = applied
            self.reported = reported
            self.finished = finished
            self.failureHandlers = failureHandlers
        }

        /// The same observers with another `applied` observer.
        func withApplied(_ observer: @escaping ([AppliedChange]) -> Void) -> Observers {
            Observers(applied: observer, reported: reported, finished: finished, failureHandlers: failureHandlers)
        }

        /// The same observers with another `reported` observer.
        func withReported(_ observer: @escaping (NavigationIssue) -> Void) -> Observers {
            Observers(applied: applied, reported: observer, finished: finished, failureHandlers: failureHandlers)
        }

        /// The same observers with another `finished` observer.
        func withFinished(_ observer: @escaping (NavigationOutcome) -> Void) -> Observers {
            Observers(applied: applied, reported: reported, finished: observer, failureHandlers: failureHandlers)
        }

        /// The same observers with one more failure handler.
        func addingFailureHandler(_ handler: @escaping (NavigationFailure) -> Void) -> Observers {
            let handlers = failureHandlers + [handler]
            return Observers(
                applied: applied,
                reported: reported,
                finished: finished,
                failureHandlers: handlers
            )
        }
    }

    /// Where the tree is in the current main-actor turn.
    struct Turn {
        /// Nothing applied, nothing queued.
        static var idle: Turn {
            let emptyQueue: [() -> Void] = []
            return Turn(isApplying: false, isDraining: false, queue: emptyQueue, queuedCount: 0)
        }

        /// Whether a transaction is being applied, including its observers.
        let isApplying: Bool

        /// Whether queued calls are running.
        let isDraining: Bool

        /// Calls made while a transaction was applied, in order.
        let queue: [() -> Void]

        /// Calls queued since the queue was last empty.
        let queuedCount: Int

        /// The same turn, applying a transaction or not.
        func applying(_ isApplying: Bool) -> Turn {
            Turn(isApplying: isApplying, isDraining: isDraining, queue: queue, queuedCount: queuedCount)
        }

        /// The same turn, running queued calls or not.
        func draining(_ isDraining: Bool) -> Turn {
            Turn(isApplying: isApplying, isDraining: isDraining, queue: queue, queuedCount: queuedCount)
        }

        /// The same turn with one more queued call.
        func enqueuing(_ call: @escaping () -> Void) -> Turn {
            let longerQueue = queue + [call]
            return Turn(
                isApplying: isApplying,
                isDraining: isDraining,
                queue: longerQueue,
                queuedCount: queuedCount + 1
            )
        }

        /// The same turn with another queue. The count of queued calls is kept.
        func withQueue(_ queue: [() -> Void]) -> Turn {
            Turn(isApplying: isApplying, isDraining: isDraining, queue: queue, queuedCount: queuedCount)
        }
    }
}
