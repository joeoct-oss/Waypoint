//
//  ReadableLog.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// The readable console format: one aligned line per event, the action first, then the stack of
/// the flow on screen.
///
/// ```text
/// Waypoint  shop      push     Product (id: 42)         │ root › Product list › Product (id: 42)
/// Waypoint  shop      recover  can't go back to a screen that isn't in the stack
///                              Cart is not in the path [Product list › Product (id: 42)]. …
///                              at ShopCoordinator.swift:39
/// Waypoint  shop      back     Product (id: 42), by fallback │ root › Product list
/// ```
enum ReadableLog {
    /// The routes on screen in one flow, and whether the first one is the stack's root route.
    struct Stack {
        /// The routes, root route first when there is one.
        let routes: [AnyRoute]
        /// Whether `routes` starts with the stack's root route. Otherwise the root is a screen
        /// with no route, written as `rootName`.
        let startsWithRootRoute: Bool

        /// The name of a root screen with no route, such as `Product list`, or `root` when the
        /// stack has none, such as an empty tab container.
        let rootName: String
    }

    /// Every line starts with this, so Waypoint's lines stand out in a busy console.
    static let prefix = "Waypoint"

    /// Flow names are padded to this width, so the columns line up.
    static let flowWidth = 10

    /// Verbs are padded to this width.
    static let verbWidth = 8

    /// Subjects are padded to this width before the stack column.
    static let subjectWidth = 24

    /// A stack with more routes than this above its root is shortened in change lines.
    static let longStack = 4

    /// `Waypoint  shop      push     Product (id: 42)`.
    static func line(_ flow: FlowID, _ verb: String, _ subject: String) -> String {
        "\(prefix)  \(padded(flow.name, flowWidth)) \(padded(verb, verbWidth)) \(subject)"
    }

    /// A line with the stack after the subject: `… push     Product (id: 42)  │ root › …`.
    static func line(_ flow: FlowID, _ verb: String, _ subject: String, stack: String, symbols: Bool) -> String {
        let bar = symbols ? "│" : "|"
        return line(flow, verb, "\(padded(subject, subjectWidth)) \(bar) \(stack)")
    }

    /// The lines after the first one, indented under the subject.
    static func continuation(_ lines: [String]) -> String {
        let indent = String(repeating: " ", count: prefix.count + 2 + flowWidth + 1 + verbWidth + 1)
        return lines.map { "\n\(indent)\($0)" }.joined()
    }

    /// One applied change, with the stack of the flow on screen after it, when known.
    static func change(_ applied: AppliedChange, stack: Stack?, naming: RouteNaming) -> String {
        let (verb, subject) = describe(applied.change, naming: naming)
        let full = subject + originText(applied.origin, after: subject)
        guard let stack else {
            return line(applied.flow, verb, full)
        }
        let stackText = stackText(stack, naming: naming, shortens: true)
        return line(applied.flow, verb, full, stack: stackText, symbols: naming.usesSymbols)
    }

    /// `, by fallback` or `, by user` after a subject, or `by user` alone, or nothing for a
    /// change app code asked for.
    private static func originText(_ origin: ChangeOrigin, after subject: String) -> String {
        let separator = subject.isEmpty ? "" : ", "
        switch origin {
        case .app:
            return ""
        case .fallback:
            return separator + "by fallback"
        case .user:
            return separator + "by user"
        }
    }

    /// An issue: a headline, the message, and the call site.
    static func issue(_ issue: NavigationIssue, recovered: Bool, naming: RouteNaming) -> String {
        let head = line(issue.flow, recovered ? "recover" : "fail", headline(issue.kind))
        return head + continuation([issue.message(in: naming), "at \(issue.callSite)"])
    }

    /// A call that changed nothing.
    static func unchanged(_ flow: FlowID, site: String, symbols: Bool) -> String {
        line(flow, "same", "already there (\(site))")
    }

    /// A push skipped because the same route is still being pushed, such as a double tap.
    static func skippedPush(_ flow: FlowID, route: AnyRoute, site: String, naming: RouteNaming) -> String {
        line(flow, "skip", "\(naming.name(route)) is still being pushed (\(site))")
    }

    /// A call queued behind the change being applied.
    static func queued(_ flow: FlowID, site: String, symbols: Bool) -> String {
        line(flow, "queue", "waits for the current change to end (\(site))")
    }

    /// A change the screen holds until the running transition ends.
    static func held(_ flow: FlowID, milliseconds: Int64, symbols: Bool) -> String {
        line(flow, "hold", "waits \(milliseconds) ms for the running transition")
    }

    /// A call on a router that left the tree.
    static func ignored(_ flow: FlowID, site: String, symbols: Bool) -> String {
        line(flow, "ignore", "this flow is closed (\(site))")
    }

    /// The stack of one flow after a change, in full.
    static func stack(_ flow: FlowID, _ stack: Stack, naming: RouteNaming) -> String {
        line(flow, "stack", stackText(stack, naming: naming, shortens: false))
    }

    /// A breadcrumb that starts at the root screen: `Shop › Product list › Product (id: 42)`. When
    /// `shortens` is on, a stack deeper than ``longStack`` keeps the root, the first route and the
    /// last two, and ends with its depth: `Shop › Product (id: 2) › … › Product (id: 6) (5)`.
    static func stackText(_ stack: Stack, naming: RouteNaming, shortens: Bool) -> String {
        let root = stack.startsWithRootRoute ? stack.routes.first.map(naming.name) : stack.rootName
        let pushed = stack.startsWithRootRoute ? Array(stack.routes.dropFirst()) : stack.routes
        let separator = naming.usesSymbols ? " › " : " > "
        guard shortens, pushed.count > longStack else {
            return ([root].compactMap { $0 } + pushed.map(naming.name)).joined(separator: separator)
        }
        let kept = [pushed[0]].map(naming.name) + ["…"] + pushed.suffix(2).map(naming.name)
        return ([root].compactMap { $0 } + kept).joined(separator: separator) + " (\(pushed.count))"
    }

    /// A problem found while registering a route type.
    static func registryProblem(_ problem: RouteDecodingError, symbols: Bool) -> String {
        line(FlowID("registry"), "error", problem.description)
    }

    /// `name` with spaces after it up to `width`, and one space at least.
    private static func padded(_ name: String, _ width: Int) -> String {
        name.padding(toLength: max(width, name.count), withPad: " ", startingAt: 0)
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
        case .rendererMismatch:
            return "the screen showed something the router can't match"
        case .missingDestination:
            return "this stack has no destination for this screen"
        case .routerNotFromWaypoint:
            return "this coordinator stores its own router"
        case .routerOwnedByAnotherCoordinator:
            return "this coordinator uses another coordinator's router"
        case .rootNameReplaced:
            return "rootName replaced the root name makeRouter() set"
        case .releasedRouterReturned:
            return "makeRouter() returned a router that already ended"
        }
    }

    /// The verb and subject of one change.
    private static func describe(_ change: NavigationChange, naming: RouteNaming) -> (String, String) {
        switch change {
        case .pushed(let routes):
            return ("push", naming.path(routes))
        case .popped(let routes):
            return ("back", naming.path(routes))
        case .replaced:
            return ("set", "")
        case .presented(let presentation):
            return ("present", "\(presentation.style) \(presentation.flow)")
        case .dismissed(let flow):
            return ("dismiss", flow.name)
        case .tabSelected(let old, let new):
            return ("tab", tabSubject(from: old, to: new, symbols: naming.usesSymbols))
        }
    }

    /// `home → shop`.
    private static func tabSubject(from old: String, to new: String, symbols: Bool) -> String {
        "\(old) \(symbols ? "→" : "->") \(new)"
    }
}
