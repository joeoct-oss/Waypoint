//
//  NavigationTreeContext+Logging.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// The core's log call sites. Every message is built only when its level and category are
/// enabled, so a disabled log line costs nothing.
extension NavigationTreeContext {
    /// The category a change is logged in.
    private static func category(of change: NavigationChange) -> LogCategory {
        switch change {
        case .pushed, .popped, .replaced:
            return .navigation
        case .presented, .dismissed:
            return .presentation
        case .tabSelected:
            return .tabs
        }
    }

    /// `pushed [ProductRoute(id: <private>)] flow=main`, with `origin=fallback` for a fallback.
    private static func changeLine(_ applied: AppliedChange, revealingPrivateValues: Bool) -> String {
        let change = applied.change.debugDescription(revealingPrivateValues: revealingPrivateValues)
        let origin = applied.origin == .fallback ? " origin=fallback" : ""
        return "\(change) flow=\(applied.flow)\(origin)"
    }

    /// The file name and line, such as `ShopCoordinator.swift:42`.
    private static func callSite(_ file: StaticString, _ line: UInt) -> String {
        let path = "\(file)"
        let name = path.split(separator: "/").last.map(String.init) ?? path
        return "\(name):\(line)"
    }

    /// Writes one message, built only when enabled.
    func log(
        _ level: LogLevel,
        _ category: LogCategory,
        file: StaticString,
        line: UInt,
        _ text: (_ revealingPrivateValues: Bool) -> String
    ) {
        let configuration = logging
        guard configuration.isEnabled(level: level, category: category) else {
            return
        }
        let message = text(configuration.revealsPrivateValues)
        configuration.handler.log(LogMessage(level: level, category: category, text: message, file: file, line: line))
    }

    /// Logs each applied change at `.info`, in the category of its kind.
    func logChanges(_ changes: [AppliedChange], file: StaticString, line: UInt) {
        for applied in changes {
            log(.info, Self.category(of: applied.change), file: file, line: line) { reveal in
                Self.changeLine(applied, revealingPrivateValues: reveal)
            }
        }
    }

    /// Logs an issue in the `issues` category, with its message on the next line.
    func logIssue(_ issue: NavigationIssue, level: LogLevel) {
        log(level, .issues, file: issue.file, line: issue.line) { reveal in
            issue.debugDescription(revealingPrivateValues: reveal)
        }
    }

    /// Logs a call that changed nothing, at `.debug`.
    func logUnchanged(_ outcome: NavigationOutcome, flow: FlowID, file: StaticString, line: UInt) {
        guard outcome == .alreadyThere else {
            return
        }
        log(.debug, .navigation, file: file, line: line) { _ in
            "alreadyThere flow=\(flow) at=\(Self.callSite(file, line))"
        }
    }

    /// Logs a call queued behind a change, at `.debug` (decision 0013).
    func logQueued(_ flow: FlowID, file: StaticString, line: UInt) {
        log(.debug, .navigation, file: file, line: line) { _ in
            "reentrantChange flow=\(flow) at=\(Self.callSite(file, line))"
        }
    }

    /// Logs a call on a router that left the tree, at `.debug` (decision 0013).
    func logIgnored(_ flow: FlowID, file: StaticString, line: UInt) {
        log(.debug, .navigation, file: file, line: line) { _ in
            "staleNavigator flow=\(flow) at=\(Self.callSite(file, line))"
        }
    }

    /// Logs a problem found while registering a route type, at `.error`.
    func logRegistryProblem(_ problem: RouteDecodingError) {
        log(.error, .issues, file: #fileID, line: #line) { reveal in
            problem.debugDescription(revealingPrivateValues: reveal)
        }
    }

    /// Starts the interval of one transaction, when intervals are measured.
    func beginTransactionInterval() -> LogInterval? {
        let configuration = logging
        guard configuration.measuresIntervals(in: .navigation) else {
            return nil
        }
        let interval = LogInterval(name: "transaction", category: .navigation, id: claimIntervalID())
        configuration.handler.beginInterval(interval)
        return interval
    }

    /// Ends the interval of one transaction, also when it failed.
    func endTransactionInterval(_ interval: LogInterval?) {
        guard let interval else {
            return
        }
        logging.handler.endInterval(interval)
    }
}
