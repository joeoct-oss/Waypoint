//
//  Tuist.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// Tuist's settings for the example app. The Tuist version is pinned with mise (#80). The project
// is linked to its Tuist server project, which keeps the selective testing results that
// `scripts/test-mac.sh` uses (#312, #324; the binary cache stays off); the Mac signs in once with
// `tuist auth login`.
// `enableCaching` adds Xcode's compilation cache settings to the generated project, backed by
// Tuist's remote cache; `tuist setup cache` installs the local proxy it talks to, once per Mac.

import ProjectDescription

let tuistProject = "joeoct91/waypoint"

let tuist = Tuist(
    fullHandle: tuistProject,
    project: .tuist(
        generationOptions: .options(
            enableCaching: true
        )
    )
)
