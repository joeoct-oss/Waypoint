//
//  WaypointExampleApp.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import UIKit

// The example app. It holds only what every window shares (the launch options and the services:
// the local store, the session and the mock auth service), and asks the app coordinator for each
// window's view. Each window gets its own coordinator, so two windows never share a path.
@main
struct WaypointExampleApp: App {
    private let launch: LaunchOptions
    private let services: AppServices

    init() {
        let launch = LaunchOptions(defaults: .standard)
        self.launch = launch
        services = AppServices(launch: launch)
        Self.speedUpAnimationsIfAsked()
    }

    // Experiment: `-animationSpeed N` plays every animation N times faster, in every window the
    // app shows, to measure how much of a UI test run is spent waiting for animations.
    private static func speedUpAnimationsIfAsked() {
        let speed = UserDefaults.standard.double(forKey: LaunchArgument.animationSpeed.rawValue)
        guard speed > 1 else {
            return
        }
        NotificationCenter.default.addObserver(
            forName: UIWindow.didBecomeVisibleNotification,
            object: nil,
            queue: .main
        ) { note in
            MainActor.assumeIsolated {
                (note.object as? UIWindow)?.layer.speed = Float(speed)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            AppCoordinator.makeWindow(
                services: services,
                launch: launch
            )
        }
    }
}
