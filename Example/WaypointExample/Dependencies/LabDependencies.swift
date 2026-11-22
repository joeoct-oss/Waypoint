//
//  LabDependencies.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import WaypointCore

// What the Navigation Lab's demo flows use, from `AppServices.labDependencies()`: the catalog its
// product demos show, and the navigation configuration its own routers start with.
struct LabDependencies {
    let catalog: any ProductCatalog
    let navigation: NavigationConfiguration
}
