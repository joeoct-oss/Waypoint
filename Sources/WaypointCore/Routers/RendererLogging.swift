//
//  RendererLogging.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// What renderers add to the tree's logs: the platform's default log handler, a signpost interval
// for each push the screen animates, and a line for each change held until a transition ends.
// They are `package`, so only Waypoint's own renderers and testing library can call them.

extension StackRouter {
    /// Writes the whole tree's logs to `makeHandler()` when the app gave no handler in the root's
    /// ``NavigationConfiguration``. A handler the app chose, `.disabled` included, is kept.
    /// Renderers call it with the unified log handler before they draw the tree.
    ///
    /// Returns whether the handler was installed. Only the first call on a tree can install one.
    @discardableResult
    package func installDefaultLogHandler(_ makeHandler: () -> any LogHandler) -> Bool {
        tree.installDefaultLogHandler(makeHandler)
    }

    /// Logs, at `.debug` in `renderer`, that the screen holds a change until the running
    /// transition ends, in `wait`.
    package func rendererDidHoldChange(for wait: Duration, file: StaticString = #fileID, line: UInt = #line) {
        let flow = flowID
        let milliseconds = Self.milliseconds(wait)
        tree.log(.debug, .renderer, file: file, line: line) { naming in
            naming.format == .readable
                ? ReadableLog.held(flow, milliseconds: milliseconds, symbols: naming.usesSymbols)
                : "heldChange flow=\(flow) wait=\(milliseconds)ms"
        }
    }

    /// A duration in whole milliseconds, rounded down.
    private static func milliseconds(_ duration: Duration) -> Int64 {
        let (seconds, attoseconds) = duration.components
        return seconds * 1_000 + attoseconds / 1_000_000_000_000_000
    }

    /// Starts a `push` interval in `renderer`, when intervals are measured. A push
    /// still running is ended first, because a newer push replaced it.
    func beginPushInterval() {
        endPushInterval()
        pushInterval = tree.beginInterval(named: "push", in: .renderer)
    }

    /// Ends the running `push` interval, if any.
    func endPushInterval() {
        tree.endInterval(pushInterval)
        pushInterval = nil
    }
}

extension TabRouter {
    /// Writes the whole tree's logs to `makeHandler()` when the app gave no handler in the root's
    /// ``NavigationConfiguration``. A handler the app chose, `.disabled` included, is kept.
    /// Renderers call it with the unified log handler before they draw the tree.
    ///
    /// Returns whether the handler was installed. Only the first call on a tree can install one.
    @discardableResult
    package func installDefaultLogHandler(_ makeHandler: () -> any LogHandler) -> Bool {
        tree.installDefaultLogHandler(makeHandler)
    }
}
