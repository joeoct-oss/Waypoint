//
//  WaypointExampleApp.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// The example app. It holds the app coordinator and nothing else, and draws it in one window.
@main
struct WaypointExampleApp: App {
    @State private var app = AppCoordinator(launch: LaunchOptions(defaults: .standard))

    var body: some Scene {
        WindowGroup {
            AppRootView(app: app)
        }
    }
}
