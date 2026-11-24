//
//  StackCoordinator.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

#if canImport(SwiftUI)
    import SwiftUI
#endif

#if canImport(SwiftUI)
    /// App code that owns one stack flow, with its screens.
    ///
    /// A coordinator writes only what is its own: its `root` screen, its `destinations`, and its
    /// logic. Conforming fills in the rest, as `StackCoordinating` describes: the router, made
    /// the first time it is read, named after the coordinator and given every route type in
    /// `destinations`, and `view`, the whole flow drawn by `Renderer`.
    ///
    /// ```swift
    /// final class ShopCoordinator: StackCoordinator {
    ///     var root: some View {
    ///         ProductListView(onSelect: { self.showProduct(id: $0) })
    ///     }
    ///
    ///     var destinations: some Destinations {
    ///         Destination(ProductRoute.self) { route in
    ///             ProductView(id: route.id)
    ///         }
    ///     }
    ///
    ///     func showProduct(id: Int) {
    ///         router.push(ProductRoute(id: id))
    ///     }
    /// }
    ///
    /// // Where the flow shows, such as a tab:
    /// shop.view
    /// ```
    ///
    /// A screen can be a SwiftUI view or, where UIKit is, a view controller.
    ///
    /// Conformances:
    /// - `StackCoordinating`, the core protocol with the router and its defaults, which has no UI
    ///   so a coordinator's logic is tested on Linux.
    @MainActor
    public protocol StackCoordinator: StackCoordinating {
        /// The flow's first screen.
        associatedtype RootScreen: View

        /// The flow's screens, by route type. Default: ``EmptyDestinations``.
        associatedtype Screens: Destinations = EmptyDestinations

        /// What draws the flow. Default: ``DefaultStackRenderer``.
        associatedtype Renderer: StackRenderer = DefaultStackRenderer<Self> where Renderer.Coordinator == Self

        /// The flow's first screen, a SwiftUI view or a view controller.
        @ScreenBuilder var root: RootScreen { get }

        /// The flow's screens, by route type. Default: none, for a flow of one screen.
        @DestinationsBuilder var destinations: Screens { get }

        /// The whole flow, drawn by `Renderer`. Default: filled in by Waypoint.
        var view: Renderer { get }
    }

    extension StackCoordinator where Screens == EmptyDestinations {
        /// No screens but the root.
        public var destinations: EmptyDestinations {
            EmptyDestinations()
        }
    }

    extension StackCoordinator {
        /// The flow, drawn by `Renderer`.
        public var view: Renderer {
            Renderer(coordinator: self)
        }

        /// Registers every route type in ``destinations``, with its screen's name for the journey.
        public func registerDestinations(on router: StackRouter) {
            destinations.registerRoutes(on: router)
        }
    }
#else
    /// App code that owns one stack flow. Its screens are drawn where SwiftUI is.
    ///
    /// Conformances:
    /// - `StackCoordinating`, the core protocol with the router and its defaults.
    @MainActor
    public protocol StackCoordinator: StackCoordinating { }
#endif
