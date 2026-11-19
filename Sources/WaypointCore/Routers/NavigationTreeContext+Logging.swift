//
//  NavigationTreeContext+Logging.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
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

    /// `pushed [ProductRoute(id: <private>)] flow=main`, with `origin=fallback` for a fallback and
    /// `origin=user` for a change the user made directly.
    /// A presentation names the flow that presented it as `presenter=`, since the presented
    /// flow is already in the change.
    private static func structuredChangeLine(_ applied: AppliedChange, naming: RouteNaming) -> String {
        let change = applied.change.debugDescription(revealingPrivateValues: naming.revealsPrivateValues)
        let key = isPresentation(applied.change) ? "presenter" : "flow"
        let origin = structuredOrigin(applied.origin)
        return "\(change) \(key)=\(applied.flow)\(origin)"
    }

    /// ` origin=fallback` or ` origin=user`, or nothing for a change app code asked for.
    private static func structuredOrigin(_ origin: ChangeOrigin) -> String {
        switch origin {
        case .app:
            return ""
        case .fallback:
            return " origin=fallback"
        case .user:
            return " origin=user"
        }
    }

    /// Whether a change presents or dismisses a flow.
    private static func isPresentation(_ change: NavigationChange) -> Bool {
        switch change {
        case .presented, .dismissed:
            return true
        case .pushed, .popped, .replaced, .tabSelected:
            return false
        }
    }

    /// The flow whose stack is worth showing after a change: the presented flow for a
    /// presentation, otherwise the flow that changed.
    private static func shownFlow(after applied: AppliedChange) -> FlowID {
        guard case .presented(let presentation) = applied.change else {
            return applied.flow
        }
        return presentation.flow
    }

    /// The file name and line, such as `ShopCoordinator.swift:42`.
    static func callSite(_ file: StaticString, _ line: UInt) -> String {
        let path = "\(file)"
        let name = path.split(separator: "/").last.map(String.init) ?? path
        return "\(name):\(line)"
    }

    /// Writes one message, built only when enabled, with routes named the configured way.
    func log(
        _ level: LogLevel,
        _ category: LogCategory,
        file: StaticString,
        line: UInt,
        _ text: (RouteNaming) -> String
    ) {
        let configuration = logging
        guard configuration.isEnabled(level: level, category: category) else {
            return
        }
        let message = text(RouteNaming(configuration))
        configuration.handler.log(LogMessage(level: level, category: category, text: message, file: file, line: line))
    }

    /// Logs each applied change at `.debug`, in the category of its kind, then the tree when
    /// asked. The journey box says what the user sees at `.info`; these say how the routers got
    /// there.
    func logChanges(_ changes: [AppliedChange], in router: some TreeNode, file: StaticString, line: UInt) {
        let root = router.rootNode
        for applied in changes {
            log(.debug, Self.category(of: applied.change), file: file, line: line) { naming in
                changeLine(applied, root: root, naming: naming)
            }
        }
        logTree(after: changes, root: root, file: file, line: line)
    }

    /// Logs what the journey wrote for a change in the `navigation` category: in the readable
    /// format one box at `.info`, or at `.notice` when it holds a duplicate warning; in the
    /// structured format one line per entry.
    func logJourney(_ entries: [JourneyEntry], root: any TreeNode, file: StaticString, line: UInt) {
        guard !entries.isEmpty else {
            return
        }
        guard logging.format == .readable else {
            for entry in entries {
                log(Self.level(of: entry), .navigation, file: file, line: line) { _ in
                    JourneyLog.line(entry)
                }
            }
            return
        }
        let level = entries.map(Self.level).max() ?? .info
        log(level, .navigation, file: file, line: line) { naming in
            let box = JourneyBox(entries: entries, visible: VisibleScreen(in: root), root: root, naming: naming)
            return box.rendered ?? ""
        }
    }

    /// The level of a journey entry: `.notice` for a duplicate, else `.info`.
    private static func level(of entry: JourneyEntry) -> LogLevel {
        guard case .duplicate = entry else {
            return .info
        }
        return .notice
    }

    /// Logs issues in the `issues` category: a recovered one at `.error`, a failed one at
    /// `.fault`.
    func logIssues(_ issues: [(issue: NavigationIssue, level: LogLevel)]) {
        for (issue, level) in issues {
            logIssue(issue, level: level)
        }
    }

    /// Logs one issue in the `issues` category, with its message on the next lines.
    func logIssue(_ issue: NavigationIssue, level: LogLevel) {
        log(level, .issues, file: issue.file, line: issue.line) { naming in
            issueLine(issue, level: level, naming: naming)
        }
    }

    /// Logs a call that changed nothing, at `.debug`, naming the push it skipped, if any.
    func logUnchanged(
        _ outcome: NavigationOutcome,
        flow: FlowID,
        skippedPush: AnyRoute?,
        file: StaticString,
        line: UInt
    ) {
        guard outcome == .alreadyThere else {
            return
        }
        let site = Self.callSite(file, line)
        log(.debug, .navigation, file: file, line: line) { naming in
            Self.unchangedLine(flow, skippedPush: skippedPush, site: site, naming: naming)
        }
    }

    /// A call that changed nothing, in the configured format.
    private static func unchangedLine(
        _ flow: FlowID,
        skippedPush: AnyRoute?,
        site: String,
        naming: RouteNaming
    ) -> String {
        switch (naming.format == .readable, skippedPush) {
        case (true, .some(let route)):
            return ReadableLog.skippedPush(flow, route: route, site: site, naming: naming)
        case (true, .none):
            return ReadableLog.unchanged(flow, site: site, symbols: naming.usesSymbols)
        case (false, .some(let route)):
            return "alreadyThere flow=\(flow) skippedPush=\(naming.name(route)) at=\(site)"
        case (false, .none):
            return "alreadyThere flow=\(flow) at=\(site)"
        }
    }

    /// Logs a call queued behind a change, at `.debug` (see the Concurrency article).
    func logQueued(_ flow: FlowID, file: StaticString, line: UInt) {
        let site = Self.callSite(file, line)
        log(.debug, .navigation, file: file, line: line) { naming in
            naming.format == .readable
                ? ReadableLog.queued(flow, site: site, symbols: naming.usesSymbols)
                : "reentrantChange flow=\(flow) at=\(site)"
        }
    }

    /// Logs a call on a router that left the tree, at `.debug` (see the Concurrency article).
    func logIgnored(_ flow: FlowID, file: StaticString, line: UInt) {
        let site = Self.callSite(file, line)
        log(.debug, .navigation, file: file, line: line) { naming in
            naming.format == .readable
                ? ReadableLog.ignored(flow, site: site, symbols: naming.usesSymbols)
                : "staleNavigator flow=\(flow) at=\(site)"
        }
    }

    /// Logs a problem found while registering a route type, at `.error`.
    func logRegistryProblem(_ problem: RouteDecodingError) {
        log(.error, .issues, file: #fileID, line: #line) { naming in
            naming.format == .readable
                ? ReadableLog.registryProblem(problem, symbols: naming.usesSymbols)
                : problem.debugDescription(revealingPrivateValues: naming.revealsPrivateValues)
        }
    }

    /// Starts the interval of one transaction, when intervals are measured.
    func beginTransactionInterval() -> LogInterval? {
        beginInterval(named: "transaction", in: .navigation)
    }

    /// Ends the interval of one transaction, also when it failed.
    func endTransactionInterval(_ interval: LogInterval?) {
        endInterval(interval)
    }

    /// Starts an interval named `name` in `category`, when intervals of that category are
    /// measured, with the tree's next interval id.
    func beginInterval(named name: String, in category: LogCategory) -> LogInterval? {
        let configuration = logging
        guard configuration.measuresIntervals(in: category) else {
            return nil
        }
        let interval = LogInterval(name: name, category: category, id: claimIntervalID())
        configuration.handler.beginInterval(interval)
        return interval
    }

    /// Ends `interval`, or does nothing for `nil`.
    func endInterval(_ interval: LogInterval?) {
        guard let interval else {
            return
        }
        logging.handler.endInterval(interval)
    }

    /// One change, in the configured format.
    private func changeLine(_ applied: AppliedChange, root: any TreeNode, naming: RouteNaming) -> String {
        guard naming.format == .readable else {
            return Self.structuredChangeLine(applied, naming: naming)
        }
        let stack = root.node(for: Self.shownFlow(after: applied)).map(Self.readableStack)
        return ReadableLog.change(applied, stack: stack, naming: naming)
    }

    /// One issue, in the configured format.
    private func issueLine(_ issue: NavigationIssue, level: LogLevel, naming: RouteNaming) -> String {
        guard naming.format == .readable else {
            return issue.debugDescription(revealingPrivateValues: naming.revealsPrivateValues)
        }
        return ReadableLog.issue(issue, recovered: level < .fault, naming: naming)
    }

    /// Logs the changed stacks or the whole tree after a change, as the configuration asks.
    private func logTree(after changes: [AppliedChange], root: any TreeNode, file: StaticString, line: UInt) {
        switch logging.treeLogging {
        case .off:
            break
        case .changedStacks:
            logChangedStacks(changes, root: root, file: file, line: line)
        case .wholeTree:
            logWholeTree(root, file: file, line: line)
        }
    }

    /// One line per changed flow with the routes it shows.
    private func logChangedStacks(_ changes: [AppliedChange], root: any TreeNode, file: StaticString, line: UInt) {
        let flows = changes.map(Self.shownFlow).reduce(into: [FlowID]()) { flows, flow in
            flows += flows.contains(flow) ? [] : [flow]
        }
        for flow in flows {
            guard let stack = root.node(for: flow)?.shownStack else {
                continue
            }
            log(.debug, .navigation, file: file, line: line) { naming in
                Self.stackLine(stack, naming: naming)
            }
        }
    }

    /// The whole tree, one flow per line.
    private func logWholeTree(_ root: any TreeNode, file: StaticString, line: UInt) {
        log(.debug, .navigation, file: file, line: line) { naming in
            "tree after the change:\n" + root.readableTree(naming).rendered
        }
    }

    /// `Waypoint  shop       stack    root › Product list (…)`, or `stack flow=shop path=[…]`.
    private static func stackLine(_ stack: any TreeNode, naming: RouteNaming) -> String {
        guard naming.format == .readable else {
            return "stack flow=\(stack.flowID) path=\(naming.list(stack.shownRoutes))"
        }
        return ReadableLog.stack(stack.flowID, readableStack(stack), naming: naming)
    }

    /// The routes a flow shows, and whether they start with its root route.
    private static func readableStack(_ node: any TreeNode) -> ReadableLog.Stack {
        let rootName = (node.shownStack as? StackRouter).map(VisibleScreen.rootName(of:)) ?? "root"
        return ReadableLog.Stack(routes: node.shownRoutes, startsWithRootRoute: node.showsRootRoute, rootName: rootName)
    }
}
