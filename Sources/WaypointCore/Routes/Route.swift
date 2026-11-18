//
//  Route.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
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
/// The coordinator supplies a screen's model from the route's id. To show what a list already
/// loaded at once, mark an optional field ``RouteHint``; it is never saved, compared or described.
///
/// Conformances:
/// - `NavigationValue`, so the router can compare routes and find them in a path, routes can be
///   saved, restored and built from links, and they can be logged and tracked off the main actor.
public protocol Route: NavigationValue {
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
