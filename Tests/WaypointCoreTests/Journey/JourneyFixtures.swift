//
//  JourneyFixtures.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import WaypointTestSupport

@testable import WaypointCore

/// Routes and helpers that only the journey tests use.
enum JourneyFixtures {
    /// A product page that shows its id and its title in the journey.
    ///
    /// Conformances:
    /// - `TrackableScreen`, so the journey names it with its title.
    struct ItemRoute: TrackableScreen {
        /// Fields that hold no user data.
        static let publicLogFields: Set<String> = ["id"]

        /// The journey's name for the screen.
        static let screenName = "Product"

        /// The product identifier.
        let id: Int

        /// The product's title, shown as the screen's display name.
        let title: String?

        /// The title.
        var screenDisplayName: String? {
            title
        }
    }

    /// A product list.
    ///
    /// Conformances:
    /// - `Route`, so it can be pushed with its default journey name.
    struct ProductListRoute: Route { }

    /// A search screen, which becomes the source of what it opens.
    ///
    /// Conformances:
    /// - `TrackableScreen`, so it starts a journey.
    struct SearchRoute: TrackableScreen {
        /// Search starts a journey.
        static let startsJourney = true
    }

    /// A loading step that isn't a screen to a person.
    ///
    /// Conformances:
    /// - `TrackableScreen`, so the journey leaves it out.
    struct LoadingRoute: TrackableScreen {
        /// Not tracked.
        static let isTracked = false
    }

    /// The first screen of a three-step checkout.
    ///
    /// Conformances:
    /// - `TrackableScreen`, so the journey counts the checkout's steps.
    struct CheckoutRoute: TrackableScreen {
        /// Address, payment and review.
        static let stepsInFlow: Int? = 3
    }

    /// A checkout step after the first.
    ///
    /// Conformances:
    /// - `Route`, so it can be pushed in the checkout; its cases name the steps.
    enum CheckoutStep: Route {
        /// Payment.
        case payment
        /// Review.
        case review
    }

    /// A form pushed on the side of the checkout, not one of its steps.
    ///
    /// Conformances:
    /// - `TrackableScreen`, so it isn't counted as a step.
    struct AddressFormRoute: TrackableScreen {
        /// Not a step.
        static let isFlowStep = false
    }

    /// A clock the test moves by hand.
    @MainActor
    final class ManualClock {
        /// The time now.
        ///
        /// `var` because the test moves it. Only ``advance(by:)`` changes it.
        private(set) var now = Duration.zero

        /// Moves the clock forward.
        func advance(by duration: Duration) {
            now += duration
        }
    }

    /// A stack router whose tree logs from `.debug` to `handler`, with a manual clock.
    @MainActor
    static func stack(
        _ handler: RecordingLogHandler,
        clock: ManualClock,
        logging: LogConfiguration = LogConfiguration()
    ) -> StackRouter {
        let configured = logging.withHandler(handler).withMinimumLevel(.debug)
        let router = StackRouter(configuration: NavigationConfiguration(logging: configured, registry: .permissive))
        router.tree.journeyClock = {
            clock.now
        }
        return router
    }

    /// A tab router with every `MainTab`, whose tree logs from `.debug` to `handler`, with a
    /// manual clock.
    @MainActor
    static func tabs(_ handler: RecordingLogHandler, clock: ManualClock) -> TabRouter<MainTab> {
        let logging = LogConfiguration(handler: handler, minimumLevel: .debug)
        let configuration = NavigationConfiguration(logging: logging, registry: .permissive)
        let tabs = TabRouter(selection: MainTab.home, configuration: configuration)
        tabs.tree.journeyClock = {
            clock.now
        }
        return tabs
    }
}
