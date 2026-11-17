//
//  RouteNaming.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// How routes and paths are named in a log line or an issue message.
///
/// Conformances:
/// - `Sendable`, so issue messages can be built from it off the main actor.
struct RouteNaming: Sendable {
    /// The structured form with private values hidden, used for `NavigationIssue.message`.
    static let structured = RouteNaming(format: .structured, revealsPrivateValues: false, usesSymbols: false)

    /// The form of the names.
    let format: LogFormat

    /// Whether route field values are shown.
    let revealsPrivateValues: Bool

    /// Whether readable paths use `›` between routes, instead of `>`.
    let usesSymbols: Bool

    /// The naming for a log configuration.
    init(_ configuration: LogConfiguration) {
        self.init(
            format: configuration.format,
            revealsPrivateValues: configuration.revealsPrivateValues,
            usesSymbols: configuration.usesSymbols
        )
    }

    /// Creates a naming.
    init(format: LogFormat, revealsPrivateValues: Bool, usesSymbols: Bool) {
        self.format = format
        self.revealsPrivateValues = revealsPrivateValues
        self.usesSymbols = usesSymbols
    }

    /// `ProductRoute(id: <private>)`, or readable `Product (…)`.
    func name(_ route: AnyRoute) -> String {
        switch format {
        case .readable:
            return route.readableDescription(revealingPrivateValues: revealsPrivateValues)
        case .structured:
            return route.debugDescription(revealingPrivateValues: revealsPrivateValues)
        }
    }

    /// `ProductRoute`, or readable `Product`.
    func typeName(_ key: RouteKey) -> String {
        switch format {
        case .readable:
            return RouteDescriber.readableTypeName(key.typeName)
        case .structured:
            return key.typeName
        }
    }

    /// `[A, B]`, or readable `[A › B]`.
    func list(_ routes: [AnyRoute]) -> String {
        switch format {
        case .readable:
            return "[\(path(routes))]"
        case .structured:
            return DescriptionFormat.list(routes, revealingPrivateValues: revealsPrivateValues)
        }
    }

    /// Readable routes joined as a breadcrumb: `Product list › Product (…)`.
    func path(_ routes: [AnyRoute]) -> String {
        routes.map(name).joined(separator: usesSymbols ? " › " : " > ")
    }
}
