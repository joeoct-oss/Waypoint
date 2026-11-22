//
//  TestStore.swift
//  WaypointExampleTests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Foundation
@testable import WaypointExample

// Stores and launch options for tests. Each store gets a domain of its own, so tests never share
// data with each other or with the app. A test clears its store when it ends.
enum TestStore {
    private static let domainPrefix = "dev.waypoint.example.tests."

    static func make() -> LocalStore {
        LocalStore(domain: domainPrefix + UUID().uuidString)
    }

    // The launch options of a plain launch: no launch arguments, read from an empty domain.
    static func launchOptions() -> LaunchOptions {
        let domain = domainPrefix + UUID().uuidString
        let defaults = UserDefaults(suiteName: domain) ?? .standard
        return LaunchOptions(defaults: defaults)
    }
}
