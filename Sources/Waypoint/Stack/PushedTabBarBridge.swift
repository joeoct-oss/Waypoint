//
//  PushedTabBarBridge.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

#if canImport(UIKit) && os(iOS)
    import SwiftUI
    import UIKit
    import os

    /// Sets `hidesBottomBarWhenPushed` on the controller UIKit pushes for one pushed screen, so
    /// UIKit slides the tab bar away with it. It sits in the screen's background, inside the
    /// hosting controller SwiftUI makes for the screen.
    ///
    /// Conformances:
    /// - `UIViewControllerRepresentable`, so it joins the screen's controllers.
    struct PushedTabBarBridge: UIViewControllerRepresentable {
        /// Called once when no controller above the bridge is the child of a navigation
        /// controller, so the screen falls back to SwiftUI's own way.
        let onFailure: () -> Void

        /// A controller that marks the pushed controller as soon as it joins it.
        func makeUIViewController(context: Context) -> PushedTabBarBridgeController {
            PushedTabBarBridgeController(onFailure: onFailure)
        }

        /// Nothing changes after the bridge is made.
        func updateUIViewController(_ controller: PushedTabBarBridgeController, context: Context) { }
    }

    /// The bridge's controller. It walks up its parents when it joins the screen's hosting
    /// controller, and marks the one whose parent is the navigation controller.
    final class PushedTabBarBridgeController: UIViewController {
        /// The spike's log, for when the mark lands against the push.
        private static let log = Logger(subsystem: "dev.waypoint", category: "TabBarBridge")

        /// Called once when the bridge finds no pushed controller.
        private let onFailure: () -> Void

        /// Whether the bridge has marked a controller or reported a failure.
        private var settled = false

        /// A bridge that reports `onFailure` when it can't mark a controller.
        init(onFailure: @escaping () -> Void) {
            self.onFailure = onFailure
            super.init(nibName: nil, bundle: nil)
        }

        /// Not used: the bridge is only made in code.
        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("PushedTabBarBridgeController is made in code only.")
        }

        /// A view that takes no touches and no space.
        override func loadView() {
            let view = UIView(frame: .zero)
            view.isUserInteractionEnabled = false
            view.isHidden = true
            self.view = view
        }

        /// Marks the pushed controller as early as possible, before UIKit starts the push.
        override func willMove(toParent parent: UIViewController?) {
            super.willMove(toParent: parent)
            mark(from: parent, moment: "willMove")
        }

        /// Marks the pushed controller, if the screen's controller is on the stack by now.
        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            mark(from: parent, moment: "didMove")
        }

        /// The last chance before the screen shows: usually too late for the slide.
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            mark(from: parent, moment: "viewWillAppear")
        }

        /// Reports a failure when no pushed controller was found, so the screen falls back to
        /// SwiftUI's own way.
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            mark(from: parent, moment: "viewDidAppear")
            guard !settled else {
                return
            }
            settled = true
            Self.log.notice("no pushed controller found; falling back to SwiftUI")
            onFailure()
        }

        /// Sets `hidesBottomBarWhenPushed` on the first controller above `start` whose parent is
        /// a navigation controller.
        private func mark(from start: UIViewController?, moment: StaticString) {
            guard !settled, let pushed = pushedController(from: start) else {
                return
            }
            settled = true
            pushed.hidesBottomBarWhenPushed = true
            let navigation = pushed.navigationController
            let transitioning = navigation?.transitionCoordinator != nil
            let onStack = navigation?.viewControllers.contains(pushed) ?? false
            Self.log.notice(
                "marked at \(moment, privacy: .public): onStack=\(onStack) transitioning=\(transitioning)"
            )
        }

        /// The first controller from `start` up whose parent is a navigation controller.
        private func pushedController(from start: UIViewController?) -> UIViewController? {
            var current = start
            while let controller = current {
                if controller.parent is UINavigationController {
                    return controller
                }
                current = controller.parent
            }
            return nil
        }
    }
#endif
