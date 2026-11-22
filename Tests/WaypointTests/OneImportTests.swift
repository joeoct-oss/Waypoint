//
//  OneImportTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// Not guarded by `canImport(SwiftUI)`: this file checks what `import Waypoint` alone brings in, so
// it runs on Linux too. It must not import `WaypointCore` or the test support module, or the
// check would pass without the re-export.

import Testing
import Waypoint

/// `import Waypoint` alone gives an app the core types (#304).
@Suite("One import")
@MainActor
struct OneImportTests {
    // Conformances:
    // - `Route`, so the router can push it.
    private struct ProductRoute: Route {
        let id: Int
    }

    @Test("import Waypoint alone gives routes and routers")
    func waypointAloneGivesCoreTypes() {
        let router = StackRouter()

        router.register(ProductRoute.self)
        let outcome = router.push(ProductRoute(id: 7))

        #expect(outcome == .applied)
        #expect(router.state.path.count == 1)
    }
}
