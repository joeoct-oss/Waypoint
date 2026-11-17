//
//  NavigationIssue.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// A navigation call that could not be done as asked.
///
/// A call that can only be checked at run time never crashes the app. It reports an issue with
/// the file and line of the call, and leaves the state unchanged.
///
/// Two issues are equal when every field is equal, including the file and line.
///
/// Conformances:
/// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
/// - `Equatable`, so tests and the router can compare values.
/// - `NavigationDescribable`, for a short, stable, private-by-default description in logs, events and test failures.
public struct NavigationIssue: Sendable, Equatable, NavigationDescribable {
    /// What kind of mistake an issue is.
    ///
    /// Conformances:
    /// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
    /// - `Hashable`, so kinds can be kept in sets and used as keys.
    public enum Kind: Sendable, Hashable {
        /// `popTo` a route that is not in the path.
        case routeNotInPath
        /// A pop on an empty path.
        case emptyPath
        /// A pop of more routes than the path holds.
        case notEnoughRoutes
        /// A route type with no registered destination.
        case unregisteredRoute
        /// A tab that is not one of the container's tabs, or a tab list with no tabs.
        case unknownTab
        /// A presentation while the flow already presents another one.
        case alreadyPresenting
        /// A `dismissFlow` on a flow that nobody presented.
        case notPresented
        /// A navigation handle used where no router is in scope.
        case noRouterInScope
        /// A route used through a navigator of another flow.
        case flowMismatch
        /// A guard denied the change.
        case denied
        /// A fallback could not be applied either.
        case fallbackFailed
        /// Calls queued during changes went past the tree's `maxQueuedChanges`.
        case reentrantLoop
        /// A router setting that would break a rule, such as `maxQueuedChanges` below 1. The
        /// setting keeps its old value.
        case invalidSetting
    }

    /// What went wrong.
    public let kind: Kind

    /// The flow the call was made on.
    public let flow: FlowID

    /// What went wrong and how to fix it. Route fields in it are private.
    public let message: String

    /// The file of the call, as `#fileID` gives it.
    public let file: StaticString

    /// The line of the call.
    public let line: UInt

    /// Builds the message with other route names, for readable or revealing logs. `nil` for an
    /// issue made with the public initializer, whose message is fixed.
    let describeMessage: (@Sendable (RouteNaming) -> String)?

    /// `routeNotInPath flow=shop at=ShopCoordinator.swift:42`.
    public var description: String {
        "\(kind) flow=\(flow) at=\(callSite)"
    }

    /// The file name without its module, and the line: `ShopCoordinator.swift:42`.
    public var callSite: String {
        let path = "\(file)"
        let name = path.split(separator: "/").last.map(String.init) ?? path
        return "\(name):\(line)"
    }

    /// Describes an issue.
    public init(kind: Kind, flow: FlowID, message: String, file: StaticString, line: UInt) {
        self.kind = kind
        self.flow = flow
        self.message = message
        self.file = file
        self.line = line
        self.describeMessage = nil
    }

    /// Describes an issue whose message names routes, so logs can name them their own way.
    init(
        kind: Kind,
        flow: FlowID,
        file: StaticString,
        line: UInt,
        describeMessage: @escaping @Sendable (RouteNaming) -> String
    ) {
        self.kind = kind
        self.flow = flow
        self.message = describeMessage(.structured)
        self.file = file
        self.line = line
        self.describeMessage = describeMessage
    }

    /// Whether two issues have the same kind, flow, message and call site.
    public static func == (lhs: NavigationIssue, rhs: NavigationIssue) -> Bool {
        lhs.kind == rhs.kind
            && lhs.flow == rhs.flow
            && lhs.message == rhs.message
            && "\(lhs.file)" == "\(rhs.file)"
            && lhs.line == rhs.line
    }

    /// The line, then the message on an indented second line.
    public func debugDescription(revealingPrivateValues: Bool) -> String {
        let naming = RouteNaming(format: .structured, revealsPrivateValues: revealingPrivateValues, usesSymbols: false)
        return "\(description)\n  \(message(in: naming))"
    }

    /// The message with routes named as `naming` names them.
    func message(in naming: RouteNaming) -> String {
        describeMessage?(naming) ?? message
    }
}
