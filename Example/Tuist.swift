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
// Every scheme's test action collects code coverage, and `tuist test` uploads it to the project's
// dashboard (#327). The value is the same for every run: Tuist puts it in the selective testing
// hashes, so runs with it off couldn't reuse what runs with it on passed. `prefixMapping` keeps the
// compilation cache shared across clones in builds that collect coverage (Xcode 27 or later).

import ProjectDescription

let tuistProject = "joeoct91/waypoint"

let tuist = Tuist(
    fullHandle: tuistProject,
    testInsights: .testInsights(coverage: .coverage(upload: true)),
    project: .tuist(
        generationOptions: .options(
            enableCaching: true,
            coverage: .coverage(enabled: true, prefixMapping: true)
        )
    )
)
