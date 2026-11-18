//
//  WaypointExampleApp.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// The example app. It holds no navigation: each window makes its own app coordinator, so two windows
// never share a path. App-wide services, when the app has some, stay here and are passed to each one.
@main
struct WaypointExampleApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView { makeAppCoordinator() }
        }
    }

    private func makeAppCoordinator() -> AppCoordinator {
        let launch = LaunchOptions(defaults: .standard)
        return AppCoordinator(launch: launch)
    }
}
