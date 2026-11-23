//
//  Tuist.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// Tuist's settings for the example app. The Tuist version is pinned with mise (#80). The project
// is linked to its Tuist server project, which keeps the selective testing results and the binary
// cache that `scripts/test-mac.sh` uses (#312); the Mac signs in once with `tuist auth login`.

import ProjectDescription

let tuistProject = "joeoct91/waypoint"

let tuist = Tuist(
    fullHandle: tuistProject,
    project: .tuist()
)
