//
//  WaypointExampleApp.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleNavigation
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
    }

    var body: some Scene {
        WindowGroup {
            AppCoordinator.makeWindow(
                services: services,
                launch: launch
            )
            .onAppear(perform: applyAnimationSpeed)
        }
    }

    // UI tests may run the app's animations faster (`-animationSpeed`, planning #489), so each
    // step settles sooner. Each window's layer runs at that speed, which every view, sheet and
    // transition in the window follows. The usual speed changes nothing.
    private func applyAnimationSpeed() {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        for window in windows {
            window.layer.speed = launch.animationSpeed
        }
    }
}
