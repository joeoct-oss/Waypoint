//
//  RouteFixtures.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import WaypointCore

/// Routes that only the route tests use.
enum RouteFixtures {
    /// A route with the same type name as the shared `ProductRoute`, in another module.
    ///
    /// Conformances:
    /// - `Route`, so its key can be compared with the shared one.
    struct ProductRoute: Route {
        /// The product identifier.
        let id: Int
    }

    /// A route that was renamed from `WaypointCoreTests.OldOrderRoute`.
    ///
    /// Conformances:
    /// - `Route`, so state saved under the old key decodes to it.
    struct OrderRoute: Route {
        /// The key the route had before the rename.
        static let formerRouteKeys = [RouteKey("WaypointCoreTests.OldOrderRoute")]

        /// The order identifier.
        let id: Int
    }

    /// A route that claims `OrderRoute`'s current key as a former key.
    ///
    /// Conformances:
    /// - `Route`, so the registry can report the clash.
    struct ClashingRoute: Route {
        /// Another route's current key.
        static let formerRouteKeys = [RouteKey("WaypointCoreTests.RouteFixtures.OrderRoute")]
    }

    /// A route with an empty former key.
    ///
    /// Conformances:
    /// - `Route`, so the registry can report the bad key.
    struct EmptyFormerKeyRoute: Route {
        /// A key that is not a module and type name.
        static let formerRouteKeys = [RouteKey("")]
    }

    /// A route that shows its `id` in logs and keeps its query private.
    ///
    /// Conformances:
    /// - `Route`, so its description can be checked.
    struct SearchRoute: Route {
        /// Fields that hold no user data.
        static let publicLogFields: Set<String> = ["id"]

        /// The result identifier.
        let id: Int

        /// What the user typed.
        let query: String?
    }

    /// A route that declares its own description, which Waypoint must ignore.
    ///
    /// Conformances:
    /// - `Route`, so its description can be checked.
    /// - `CustomStringConvertible`, to try to leak a field into logs.
    struct LeakyRoute: Route, CustomStringConvertible {
        /// A private value.
        let email: String

        /// A description that would leak the email.
        var description: String {
            "LeakyRoute(\(email))"
        }
    }

    /// A route enum with payloads.
    ///
    /// Conformances:
    /// - `Route`, so its cases can be compared and described.
    enum PaymentRoute: Route {
        /// A saved card.
        case card(id: Int, nickname: String)
        /// A voucher code.
        case voucher(String)
        /// Cash on delivery.
        case cash
    }

    /// A generic route, to pin how generic keys look.
    ///
    /// Conformances:
    /// - `Route`, so its key can be checked.
    /// - `Value: NavigationValue`, so the route stays a route.
    struct Box<Value: NavigationValue>: Route {
        /// The boxed value.
        let value: Value
    }

    /// A route whose stored value has the same shape as `OrderRoute`.
    ///
    /// Conformances:
    /// - `Route`, so erased equality can be checked across types.
    struct InvoiceRoute: Route {
        /// The invoice identifier.
        let id: Int
    }

    /// A product a list already loaded. Not `Hashable` or `Codable`, to show a hint needs
    /// neither.
    ///
    /// Conformances:
    /// - `Sendable`, so a route can carry it as a hint.
    struct LoadedProduct: Sendable {
        /// The product's name.
        let name: String
    }

    /// A product route that carries the loaded product as a hint, with its `id` public in logs.
    ///
    /// Conformances:
    /// - `Route`, so its saving, equality and description can be checked.
    struct HintedProductRoute: Route {
        /// Fields that hold no user data.
        static let publicLogFields: Set<String> = ["id", "preview"]

        /// The product identifier.
        let id: Int

        /// The product the list already loaded, for the first frame only.
        @RouteHint
        var preview: LoadedProduct?
    }
}

/// A route type whose key changes between builds.
///
/// Conformances:
/// - `Route`, so the registry can report its unstable key.
private struct HiddenRoute: Route { }

/// The key of the private route, for tests in other files.
let hiddenRouteKey = HiddenRoute.routeKey

/// The registry with the private route registered, for tests in other files.
func registeringHiddenRoute(in registry: RouteRegistry) -> RouteRegistry {
    registry.registering(HiddenRoute.self)
}

/// The private route, erased, for tests in other files.
let hiddenRoute = AnyRoute(HiddenRoute())
