//
//  ReadableLog.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// The readable console format: the flow first, then a symbol and a sentence.
///
/// ```text
/// shop       ▸ push Product (id: 42, …)
/// shop       ⚠︎ recovered: can't go back to a screen that isn't in the stack
///              Cart is not in the path [Product list (…) › Product (id: 42, …)]. Check contains(_:) first, …
///              at ShopCoordinator.swift:39
/// shop       ◂ back to the first screen (closed Product list (…) › Product (id: 42, …)) · by fallback
/// ```
enum ReadableLog {
    /// What a line is about, shown as a symbol, or left out when symbols are off.
    enum Marker {
        /// A push, `▸`.
        case push
        /// A pop, `◂`.
        case back
        /// A new path, `↻`.
        case set
        /// A presentation, `↑`.
        case present
        /// A dismissal, `↓`.
        case dismiss
        /// A tab selection, `⇥`.
        case tab
        /// An issue a fallback recovered, `⚠︎`.
        case recovered
        /// A failed call, `✖︎`.
        case failed
        /// A call that changed nothing, `=`.
        case same
        /// A call queued behind a change, `…`.
        case queued
        /// A call on a closed flow, `∅`.
        case ignored
        /// The stack after a change, `≡`.
        case stack
        /// A route type problem, `!`.
        case problem

        /// The symbol, such as `▸`.
        var symbol: String {
            switch self {
            case .push:
                return "▸"
            case .back:
                return "◂"
            case .set:
                return "↻"
            case .present:
                return "↑"
            case .dismiss:
                return "↓"
            case .tab:
                return "⇥"
            case .recovered:
                return "⚠︎"
            case .failed:
                return "✖︎"
            case .same:
                return "="
            case .queued:
                return "…"
            case .ignored:
                return "∅"
            case .stack:
                return "≡"
            case .problem:
                return "!"
            }
        }
    }

    /// Flow names are padded to this width, so the sentences line up.
    static let flowWidth = 10

    /// `shop       ▸ push Product (id: 42, …)`.
    static func line(_ flow: FlowID, _ marker: Marker, _ sentence: String, symbols: Bool) -> String {
        let head = flow.name.padding(toLength: max(flowWidth, flow.name.count), withPad: " ", startingAt: 0)
        guard symbols else {
            return "\(head) \(sentence)"
        }
        return "\(head) \(marker.symbol) \(sentence)"
    }

    /// The lines after the first one, indented under the sentence.
    static func continuation(_ lines: [String], symbols: Bool) -> String {
        let indent = String(repeating: " ", count: flowWidth + (symbols ? 3 : 1))
        return lines.map { "\n\(indent)\($0)" }.joined()
    }

    /// One applied change. `path` is the flow's path after the change, for "back to".
    static func change(_ applied: AppliedChange, path: [AnyRoute]?, naming: RouteNaming) -> String {
        let origin = applied.origin == .fallback ? " · by fallback" : ""
        let (marker, sentence) = describe(applied.change, path: path, naming: naming)
        return line(applied.flow, marker, sentence + origin, symbols: naming.usesSymbols)
    }

    /// An issue: a headline, the message, and the call site.
    static func issue(_ issue: NavigationIssue, recovered: Bool, naming: RouteNaming) -> String {
        let marker: Marker = recovered ? .recovered : .failed
        let verb = recovered ? "recovered" : "failed"
        let head = line(issue.flow, marker, "\(verb): \(headline(issue.kind))", symbols: naming.usesSymbols)
        let details = [issue.message(in: naming), "at \(issue.callSite)"]
        return head + continuation(details, symbols: naming.usesSymbols)
    }

    /// A call that changed nothing.
    static func unchanged(_ flow: FlowID, site: String, symbols: Bool) -> String {
        line(flow, .same, "already there (\(site))", symbols: symbols)
    }

    /// A call queued behind the change being applied.
    static func queued(_ flow: FlowID, site: String, symbols: Bool) -> String {
        line(flow, .queued, "queued until the current change ends (\(site))", symbols: symbols)
    }

    /// A call on a router that left the tree.
    static func ignored(_ flow: FlowID, site: String, symbols: Bool) -> String {
        line(flow, .ignored, "ignored: this flow is closed (\(site))", symbols: symbols)
    }

    /// The stack of one flow after a change.
    static func stack(_ flow: FlowID, routes: [AnyRoute], naming: RouteNaming) -> String {
        line(flow, .stack, stackText(routes, naming: naming), symbols: naming.usesSymbols)
    }

    /// A breadcrumb of routes, or `first screen` for an empty stack.
    static func stackText(_ routes: [AnyRoute], naming: RouteNaming) -> String {
        guard !routes.isEmpty else {
            return "first screen"
        }
        return naming.path(routes)
    }

    /// A problem found while registering a route type.
    static func registryProblem(_ problem: RouteDecodingError, symbols: Bool) -> String {
        line(FlowID("registry"), .problem, problem.description, symbols: symbols)
    }

    /// What an issue kind means, in words.
    static func headline(_ kind: NavigationIssue.Kind) -> String {
        switch kind {
        case .routeNotInPath:
            return "can't go back to a screen that isn't in the stack"
        case .emptyPath:
            return "can't go back: the first screen is already showing"
        case .notEnoughRoutes:
            return "asked to go back further than the stack goes"
        case .unregisteredRoute:
            return "no destination is registered for this screen"
        case .unknownTab:
            return "that tab isn't in this tab bar"
        case .alreadyPresenting:
            return "this flow already presents another one"
        case .notPresented:
            return "this flow wasn't presented, so it can't dismiss itself"
        case .noRouterInScope:
            return "no router is in scope for this call"
        case .flowMismatch:
            return "this route belongs to another flow"
        case .denied:
            return "a guard denied the change"
        case .fallbackFailed:
            return "the fallback failed too"
        case .reentrantLoop:
            return "too many calls were made while changes were applied"
        case .invalidSetting:
            return "a setting was refused"
        }
    }

    /// The marker and sentence of one change.
    private static func describe(
        _ change: NavigationChange,
        path: [AnyRoute]?,
        naming: RouteNaming
    ) -> (Marker, String) {
        switch change {
        case .pushed(let routes):
            return (.push, "push \(naming.path(routes))")
        case .popped(let routes):
            return (.back, backSentence(closed: routes, path: path, naming: naming))
        case .replaced(_, let new):
            return (.set, "set the stack to \(stackText(new, naming: naming))")
        case .presented(let presentation):
            return (.present, presentSentence(presentation, naming: naming))
        case .dismissed(let flow):
            return (.dismiss, "dismiss \(flow)")
        case .tabSelected(let old, let new):
            return (.tab, tabSentence(from: old, to: new, symbols: naming.usesSymbols))
        }
    }

    /// `back to Product list (closed Product (id: 42, …))`.
    private static func backSentence(closed: [AnyRoute], path: [AnyRoute]?, naming: RouteNaming) -> String {
        let closedText = "(closed \(naming.path(closed)))"
        guard let path else {
            return "back \(closedText)"
        }
        let target = path.last.map(naming.name) ?? "the first screen"
        return "back to \(target) \(closedText)"
    }

    /// `present sheet checkout: Checkout (…)`.
    private static func presentSentence(_ presentation: Presentation, naming: RouteNaming) -> String {
        let head = "present \(presentation.style) \(presentation.flow)"
        guard let route = presentation.route else {
            return head
        }
        return "\(head): \(naming.name(route))"
    }

    /// `tab home → shop`.
    private static func tabSentence(from old: String, to new: String, symbols: Bool) -> String {
        "tab \(old) \(symbols ? "→" : "->") \(new)"
    }
}
