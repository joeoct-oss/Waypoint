//
//  WaypointExampleApp.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// The example app. It holds only what every window shares (the launch options, and app-wide
// services when the app has some), and asks the app coordinator for each window's view. Each window
// gets its own coordinator, so two windows never share a path.
@main
struct WaypointExampleApp: App {
    private let launch: LaunchOptions

    init() {
        launch = LaunchOptions(defaults: .standard)
    }

    var body: some Scene {
        WindowGroup {
            AppCoordinator.makeWindow(launch: launch)
        }
    }
}
