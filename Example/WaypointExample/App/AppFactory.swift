//
//  AppFactory.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleNavigation
import SwiftUI

// Builds a window's root from the app's services: the splash, the main tabs' coordinator through
// `MainFactory`, and the view that draws the tabs. The app coordinator passes in what each reports,
// so switching the root stays in the app coordinator.
struct AppFactory {
    // The app's services, which the app coordinator clears for Clear all data.
    let services: AppServices

    init(services: AppServices) {
        self.services = services
    }

    // The main tabs, opened as `launch` asks. Clear all data runs `onClearAllData`.
    func makeMain(
        launch: LaunchOptions,
        onClearAllData: @escaping () -> Void
    ) -> MainCoordinator {
        MainFactory(services: services, launch: launch)
            .makeCoordinator(onClearAllData: onClearAllData)
    }

    // The splash, which runs `onFinished` once `duration` has passed.
    func makeSplash(
        duration: Duration,
        onFinished: @escaping () -> Void
    ) -> SplashView {
        SplashView(
            duration: duration,
            onFinished: onFinished
        )
    }

    func makeMainTabs(_ main: MainCoordinator) -> MainTabView {
        MainTabView(main: main)
    }
}
