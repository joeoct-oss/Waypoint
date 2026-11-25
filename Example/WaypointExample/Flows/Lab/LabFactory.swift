//
//  LabFactory.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import WaypointCore

// Builds the Navigation Lab's demos from `LabDependencies`: the coordinator that runs them, and the
// Detail push, Tabs and Sheet stories' coordinators, each on the Lab's navigation configuration.
// The demo coordinator passes in each story's Close.
struct LabFactory {
    private let dependencies: LabDependencies

    init(dependencies: LabDependencies) {
        self.dependencies = dependencies
    }

    // The Lab's demos. `reviewsDelay` is how long the demo reviews take to load; `nil` keeps the
    // usual delay.
    func makeDemos(reviewsDelay: Duration? = nil) -> LabDemoCoordinator {
        LabDemoCoordinator(
            factory: self,
            navigation: dependencies.navigation,
            reviewsDelay: reviewsDelay
        )
    }

    func makeDetailPush(onClose: @escaping () -> Void) -> DetailPushCoordinator {
        DetailPushCoordinator(
            navigation: dependencies.navigation,
            catalog: dependencies.catalog,
            onClose: onClose
        )
    }

    func makeTabsDemo(onClose: @escaping () -> Void) -> TabsDemoCoordinator {
        TabsDemoCoordinator(
            navigation: dependencies.navigation,
            onClose: onClose
        )
    }

    func makeSheetDemo(onClose: @escaping () -> Void) -> SheetDemoCoordinator {
        SheetDemoCoordinator(
            navigation: dependencies.navigation,
            onClose: onClose
        )
    }
}
