//
//  PushedFlowRoot.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

#if canImport(SwiftUI)
    import SwiftUI
    import WaypointCore

    /// The root screen of a child flow pushed on a stack, drawn for its marker on the parent's
    /// path, with the child's destinations, so the screens the child pushes follow on the same
    /// stack.
    ///
    /// Screens inside it see the child's router: `@StackNavigation`, `@DismissFlow`,
    /// `@Environment(StackRouter.self)` and the navigators handed to its destinations all drive the
    /// child's flow, never the parent's.
    ///
    /// Conformances:
    /// - `View`, so the stack draws it for a `ChildFlowRoute`.
    struct PushedFlowRoot: View {
        /// The marker on the parent's path where the flow starts.
        let marker: AnyRoute

        /// The router of the stack that draws the flow, at the bottom of the pushed flows.
        let stack: StackRouter

        /// The nearest stack of each flow above this one.
        @Environment(\.waypointFlowRouters) private var flowRouters

        /// The child's root screen and destinations, with its router in the environment, or
        /// nothing once the flow has ended and the stack pops its marker.
        var body: some View {
            if let parent = stack.drawnParent(ofMarker: marker),
                let router = parent.pushedFlow,
                let coordinator = parent.pushedFlowCoordinator as? any StackCoordinator
            {
                Self.screens(of: coordinator, on: router)
                    .environment(\.waypointStackRouter, router)
                    .environment(\.waypointFlowRouters, flowRouters.adding(router))
                    .environment(router)
            } else {
                #if DEBUG
                    Text(missingReason)
                        .accessibilityIdentifier(Self.missingIdentifier)
                #endif
            }
        }

        /// The accessibility identifier of the debug text shown when the flow can't be drawn.
        static let missingIdentifier = "waypoint.pushedFlow.missing"

        /// Why the flow can't be drawn, for the debug text: which lookup found nothing.
        private var missingReason: String {
            guard let parent = stack.drawnParent(ofMarker: marker) else {
                return "No pushed flow starts at \(marker). Drawn path: \(stack.drawnPath)"
            }
            guard parent.pushedFlow != nil else {
                return "The flow at \(marker) has no router."
            }
            let coordinator = parent.pushedFlowCoordinator.map { String(describing: type(of: $0)) }
            return "The flow at \(marker) has no StackCoordinator: \(coordinator ?? "none")."
        }

        /// `coordinator`'s root screen with its destinations, named for the journey.
        ///
        /// The one `AnyView` in a stack: the parent's stack can't know the type of the flow pushed
        /// on it, so the flow's root screen is wrapped once, and the screens the flow pushes keep
        /// their own types.
        private static func screens<Coordinator: StackCoordinator>(
            of coordinator: Coordinator,
            on router: StackRouter
        ) -> AnyView {
            router.setRootViewName(ViewTypeName.of(Coordinator.RootScreen.self))
            return AnyView(coordinator.root.modifier(coordinator.destinations))
        }
    }
#endif
