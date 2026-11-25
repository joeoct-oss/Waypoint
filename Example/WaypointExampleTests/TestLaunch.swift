//
//  TestLaunch.swift
//  WaypointExampleTests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCatalog
import ExampleNavigation
import ExampleTestSupport
import Foundation

extension TestStore {
    // The launch options of a plain launch: no launch arguments, read from an empty domain. With
    // `opensLab`, the launch opens the Navigation Lab, as the `lab` launch argument does.
    static func launchOptions(opensLab: Bool = false) -> LaunchOptions {
        let domain = domainPrefix + UUID().uuidString
        let defaults = UserDefaults(suiteName: domain) ?? .standard
        defaults.set(opensLab, forKey: LaunchArgument.lab.rawValue)
        let options = LaunchOptions(defaults: defaults)
        defaults.removePersistentDomain(forName: domain)
        return options
    }
}
