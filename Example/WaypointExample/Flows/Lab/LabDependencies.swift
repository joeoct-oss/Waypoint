//
//  LabDependencies.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleStore
import WaypointCore

// What the Navigation Lab's demo flows use, from `AppServices.labDependencies()`: the catalog its
// product demos show, and the navigation configuration its own routers start with.
package struct LabDependencies {
    package let catalog: any ProductCatalog
    package let navigation: NavigationConfiguration

    package init(
        catalog: any ProductCatalog,
        navigation: NavigationConfiguration
    ) {
        self.catalog = catalog
        self.navigation = navigation
    }
}
