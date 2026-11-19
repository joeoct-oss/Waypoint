//
//  StackTabBarBridge.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

#if canImport(UIKit) && os(iOS)
    import SwiftUI
    import UIKit
    import os

    /// When the slide starts against a push or pop, at `.debug`.
    private let bridgeLog = Logger(subsystem: "dev.waypoint", category: "TabBarBridge")

    /// Makes the tab bar leave with a stack's first screen when a screen is pushed above it, and
    /// come back with it on a pop. SwiftUI hides the real bar on pushed screens; the bridge puts
    /// a picture of the bar in the first screen while the push or pop runs, so the bar slides
    /// with the screen underneath, as `hidesBottomBarWhenPushed` does in UIKit. It sits in the
    /// background of the stack's first screen.
    ///
    /// UIKit's own `hidesBottomBarWhenPushed` can't be used: SwiftUI puts its own controllers
    /// between the navigation controller and the tab bar controller, so UIKit ignores the flag.
    ///
    /// Conformances:
    /// - `UIViewControllerRepresentable`, so it joins the first screen's controllers and hears
    ///   when the screen appears and disappears.
    struct StackTabBarBridge: UIViewControllerRepresentable {
        /// A controller that follows the first screen's transitions.
        func makeUIViewController(context: Context) -> StackTabBarBridgeController {
            StackTabBarBridgeController()
        }

        /// Nothing changes after the bridge is made.
        func updateUIViewController(_ controller: StackTabBarBridgeController, context: Context) { }
    }

    /// The first screen's bridge controller. When anything it needs is missing (no transition,
    /// no tab bar, no frame), it does nothing, and the bar is hidden and shown by SwiftUI alone.
    final class StackTabBarBridgeController: UIViewController {
        /// A picture of the bar taken when the first screen was last pushed over, for the pop
        /// that brings it back.
        private var cachedBar: UIView?

        /// Where the bar was, in window coordinates, when the picture was taken.
        private var cachedFrame: CGRect = .zero

        /// Where the bar was, in window coordinates, the last time the first screen showed it.
        private var shownFrame: CGRect?

        /// A view that takes no touches and no space.
        override func loadView() {
            let view = UIView(frame: .zero)
            view.isUserInteractionEnabled = false
            view.isHidden = true
            self.view = view
        }

        /// Remembers where the bar is while the first screen shows it.
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            rememberBarFrame()
        }

        /// On a push from the first screen, puts a picture of the bar in the first screen, so it
        /// slides away with it.
        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            rememberBarFrame()
            // On iOS 17 SwiftUI has already hidden the bar by now, but the window still shows the
            // last frame drawn, so the bar's place is taken from when it was last shown.
            guard animated,
                let transition = stackTransition(),
                transition.from === transition.root,
                let frame = shownFrame,
                let window = view.window ?? transition.root.view.window
            else {
                return
            }
            // The whole window under the bar, as the screen last showed it, because a picture of
            // the bar alone leaves out its glass and every tab but the selected one.
            guard let picture = barPicture(in: window, at: frame),
                let cached = barPicture(in: window, at: frame)
            else {
                return
            }
            cachedBar = cached
            cachedFrame = frame
            show(picture, at: frame, in: transition.root.view)
            bridgeLog.debug("push: bar picture placed, interactive=\(transition.coordinator.isInteractive)")
            transition.coordinator.animate(alongsideTransition: nil) { context in
                picture.removeFromSuperview()
                bridgeLog.debug("push ended, cancelled=\(context.isCancelled)")
            }
        }

        /// On a pop back to the first screen, puts the picture of the bar in the first screen,
        /// so it slides back with it. SwiftUI shows the real bar when the pop ends.
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            // The first screen only appears inside its stack when a pop brings it back. Don't
            // check the transition's ends: SwiftUI's pop to the first screen from deeper reports
            // the first screen as `from`. A real bar on screen means this is no pop from a
            // pushed screen (a full-screen cover going away, say), so no picture is needed.
            guard animated,
                let transition = stackTransition(),
                let picture = cachedBar,
                visibleTabBar() == nil
            else {
                return
            }
            show(picture, at: cachedFrame, in: transition.root.view)
            bridgeLog.debug("pop: bar picture placed, interactive=\(transition.coordinator.isInteractive)")
            transition.coordinator.animate(alongsideTransition: nil) { context in
                picture.removeFromSuperview()
                bridgeLog.debug("pop ended, cancelled=\(context.isCancelled)")
            }
        }

        /// Keeps the bar's frame while it is on screen.
        private func rememberBarFrame() {
            guard let bar = visibleTabBar() else {
                return
            }
            shownFrame = bar.convert(bar.bounds, to: nil)
        }

        /// A picture of `frame` in `window`, as last drawn.
        private func barPicture(in window: UIWindow, at frame: CGRect) -> UIView? {
            window.resizableSnapshotView(from: frame, afterScreenUpdates: false, withCapInsets: .zero)
        }

        /// The running push or pop of this stack, with the stack's first controller.
        private func stackTransition() -> StackTransition? {
            guard let navigation = navigationController,
                let root = screenController(),
                let coordinator = navigation.transitionCoordinator
            else {
                return nil
            }
            return StackTransition(
                coordinator: coordinator,
                root: root,
                from: coordinator.viewController(forKey: .from)
            )
        }

        /// The controller of the screen the bridge sits in: the one whose parent is the
        /// navigation controller. During SwiftUI's pop to the first screen from deeper, the
        /// navigation controller's first controller isn't this one yet.
        private func screenController() -> UIViewController? {
            var current = parent
            while let controller = current {
                if controller.parent is UINavigationController {
                    return controller
                }
                current = controller.parent
            }
            return nil
        }

        /// The tab bar above the stack, if it is on screen.
        private func visibleTabBar() -> UITabBar? {
            guard let bar = tabBarController?.tabBar,
                bar.window != nil,
                !bar.isHidden,
                bar.alpha > 0
            else {
                return nil
            }
            return bar
        }

        /// Puts `picture` at `frame`, given in window coordinates, on top of `container`.
        private func show(_ picture: UIView, at frame: CGRect, in container: UIView?) {
            guard let container else {
                return
            }
            picture.frame = container.convert(frame, from: nil)
            picture.isUserInteractionEnabled = false
            container.addSubview(picture)
        }
    }

    /// A push or pop of the stack the bridge sits in.
    struct StackTransition {
        /// The transition's coordinator.
        let coordinator: any UIViewControllerTransitionCoordinator

        /// The controller of the stack's first screen.
        let root: UIViewController

        /// The controller the transition leaves.
        let from: UIViewController?
    }
#endif
