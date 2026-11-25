//
//  TestStore.swift
//  ExampleTestSupport
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleServices
import Foundation

// Stores for tests. Each store gets a domain of its own, so tests never share data with each other
// or with the app. A test clears its store when it ends.
package enum TestStore {
    package static let domainPrefix = "dev.waypoint.example.tests."

    package static func make() -> LocalStore {
        LocalStore(domain: domainPrefix + UUID().uuidString)
    }
}
