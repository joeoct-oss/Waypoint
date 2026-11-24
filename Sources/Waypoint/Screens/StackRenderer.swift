//
//  StackRenderer.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

#if canImport(SwiftUI)
    import SwiftUI
    import WaypointCore

    /// What draws a stack coordinator's whole flow: its `root`, its `destinations` and the
    /// screens its router pushes.
    ///
    /// A coordinator picks one with `typealias Renderer`. Default: ``DefaultStackRenderer``.
    ///
    /// Conformances:
    /// - `View`, so the coordinator's `view` is drawn wherever it is placed.
    @MainActor
    public protocol StackRenderer: View {
        /// The coordinator it draws.
        associatedtype Coordinator: StackCoordinator

        /// A renderer that draws `coordinator`.
        init(coordinator: Coordinator)
    }

    /// The stack renderer Waypoint picks on every system: ``SwiftUIStackRenderer``.
    public typealias DefaultStackRenderer<Coordinator: StackCoordinator> = SwiftUIStackRenderer<Coordinator>

    /// Draws a stack coordinator with a ``WaypointStack`` on its router: the coordinator's `root`
    /// as the first screen, and a destination for each of its `destinations`.
    ///
    /// A coordinator drawn in two places at once is reported as `coordinatorDrawnTwice`: both
    /// would drive one router, and each stack would show the other's pushes. The check runs once
    /// the screen settles, so a view that replaces another in one update isn't reported.
    ///
    /// Conformances:
    /// - `StackRenderer`, so a coordinator can draw itself with it.
    /// - `Coordinator: StackCoordinator`: the coordinator it draws.
    public struct SwiftUIStackRenderer<Coordinator: StackCoordinator>: StackRenderer {
        /// The coordinator it draws.
        private let coordinator: Coordinator

        /// A renderer that draws `coordinator`.
        public init(coordinator: Coordinator) {
            self.coordinator = coordinator
        }

        /// The coordinator's stack.
        public var body: some View {
            let router = coordinator.router
            WaypointStack(router) {
                coordinator.root
                    .modifier(coordinator.destinations)
            }
            .onAppear {
                router.rendererDidStartDrawing(coordinator)
                Task {
                    router.rendererCheckDrawing(coordinator)
                }
            }
            .onDisappear {
                router.rendererDidStopDrawing(coordinator)
            }
        }
    }
#endif
