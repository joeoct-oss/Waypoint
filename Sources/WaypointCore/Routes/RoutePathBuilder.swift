//
//  RoutePathBuilder.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// Builds a path from routes of any type.
///
/// Conditions and loops work inside it:
///
/// ```swift
/// router.setPath {
///     ProductListRoute(category: "shoes")
///     ProductRoute(id: 42)
///     if showReviews {
///         ReviewsRoute(productID: 42)
///     }
/// }
/// ```
@resultBuilder
public enum RoutePathBuilder {
    /// One route.
    public static func buildExpression<R: Route>(_ route: R) -> [AnyRoute] {
        [AnyRoute(route)]
    }

    /// A route that is already erased.
    public static func buildExpression(_ route: AnyRoute) -> [AnyRoute] {
        [route]
    }

    /// The routes of each line, in order.
    public static func buildBlock(_ parts: [AnyRoute]...) -> [AnyRoute] {
        parts.flatMap { $0 }
    }

    /// The routes of an `if` without `else`, or none.
    public static func buildOptional(_ part: [AnyRoute]?) -> [AnyRoute] {
        part ?? []
    }

    /// The routes of the first branch of an `if`/`else` or `switch`.
    public static func buildEither(first: [AnyRoute]) -> [AnyRoute] {
        first
    }

    /// The routes of the second branch of an `if`/`else` or `switch`.
    public static func buildEither(second: [AnyRoute]) -> [AnyRoute] {
        second
    }

    /// The routes of every pass of a `for` loop, in order.
    public static func buildArray(_ parts: [[AnyRoute]]) -> [AnyRoute] {
        parts.flatMap { $0 }
    }
}
