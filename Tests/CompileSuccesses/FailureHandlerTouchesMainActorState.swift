//
//  FailureHandlerTouchesMainActorState.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// Must compile: the failure handler runs on the main actor, so it may touch main-actor state
// without `await` (#24, P6).

import WaypointCore

@MainActor
final class Banner {
    var message: String?
}

@MainActor
func makeConfiguration(banner: Banner) -> NavigationConfiguration {
    NavigationConfiguration { failure in
        banner.message = failure.issue.message
    }
}
