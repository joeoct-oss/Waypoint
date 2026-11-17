//
//  Route.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// A value that names one screen and carries its inputs.
///
/// Conforming types are usually small structs with `let` properties that hold identifiers and
/// small inputs, never models or view models. That keeps routes cheap to compare, store, log and
/// deep link into. A small enum is fine for a closed group of screens, such as the steps of a
/// wizard.
///
/// ```swift
/// // Conformances:
/// // - `Route`, so it can be pushed, presented and saved.
/// struct ProductRoute: Route {
///     let id: Int
/// }
/// ```
///
/// A route's key is its module and type name, such as `Shop.ProductRoute`, so routes declare no
/// key. See ``RouteKey``.
///
/// Conformances:
/// - `Hashable`, so the router can compare routes and find them in a path.
/// - `Codable`, so routes can be saved, restored and built from links.
/// - `Sendable`, so routes can be logged and tracked off the main actor.
public protocol Route: Hashable, Codable, Sendable {
    /// The flow this route belongs to.
    ///
    /// Leave it out and the route can be pushed onto any stack. Set it to restrict the route to
    /// one flow, checked by the compiler through a flow navigator.
    associatedtype Flow: NavigationFlow = AnyFlow

    /// Keys this route type had before it was renamed or moved, so state saved by older versions
    /// still decodes. Default: none.
    static var formerRouteKeys: [RouteKey] { get }

    /// Fields of this route that may appear in logs and descriptions unredacted. Default: none.
    ///
    /// List only fields that hold no user data, such as a product identifier.
    static var publicLogFields: Set<String> { get }
}

extension Route {
    /// No former keys.
    public static var formerRouteKeys: [RouteKey] {
        []
    }

    /// No public fields: every field prints as `<private>`.
    public static var publicLogFields: Set<String> {
        []
    }

    /// This route type's key, from its module and type name, such as `Shop.ProductRoute`.
    public static var routeKey: RouteKey {
        RouteKey(Self.self)
    }

    /// Whether this route equals another route of any type.
    func isEqual(to other: any Route) -> Bool {
        guard let other = other as? Self else {
            return false
        }
        return self == other
    }
}
