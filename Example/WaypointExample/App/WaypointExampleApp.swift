//
//  WaypointExampleApp.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleNavigation
import SwiftUI

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
        }
    }
}
