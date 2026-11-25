//
//  Tuist.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// Tuist's settings for the example app. The Tuist version is pinned with mise (planning #330). The
// project is linked to its Tuist server project, which keeps the selective testing results that
// `scripts/test-mac.sh` uses (planning #427, planning #429), and its binary cache (planning #441);
// the Mac signs in once with `tuist auth login`. `enableCaching` adds Xcode's compilation cache
// settings to the generated project, backed by Tuist's remote cache; `tuist setup cache` installs
// the local proxy it talks to, once per Mac. Every scheme's test action collects code coverage, and
// `tuist test` uploads it to the project's dashboard (planning #431). The value is the same for
// every run: Tuist puts it in the selective testing hashes, so runs with it off couldn't reuse what
// runs with it on passed. `prefixMapping` keeps the compilation cache shared across clones in
// builds that collect coverage (Xcode 27 or later).
//
// The compilation cache's local stores settle at 10 GB (`storeSizeLimit`, planning #455): without a
// limit Tuist never prunes them. On 2026-11-25 the Mac's stores held 1.2 GB (Xcode's derived data)
// and 1.3 GB (`.build/example-derived-data`), so 10 GB leaves room for many branches and stays
// bounded. After a change, the Mac runs `tuist setup cache --path Example` again so its proxy reads
// the new value.
//
// The binary cache's default profile is `none`, so `tuist generate` for work in Xcode keeps the
// package's sources editable. `scripts/test-mac.sh` sets TUIST_WAYPOINT_BINARY_CACHE=1 for the runs
// that may take prebuilt binaries (planning #441): Tuist uses one only when it was built from
// exactly the same sources, build settings and Xcode. The profile decides `tuist generate` only:
// `tuist test` takes as a binary every target outside the tests it runs, the example app's modules
// included, whatever the profile says (planning #445; on 2026-11-25 a one-line edit in
// `Flows/Cart` on `main` built only `ExampleCart` from source).

import ProjectDescription

let tuistProject = "joeoct91/waypoint"

let binaryCacheProfile: CacheProfileType =
    Environment.waypointBinaryCache.getBoolean(default: false) ? .onlyExternal : .none

let tuist = Tuist(
    fullHandle: tuistProject,
    xcodeCache: .xcodeCache(storeSizeLimit: .gigabytes(10)),
    testInsights: .testInsights(coverage: .coverage(upload: true)),
    project: .tuist(
        generationOptions: .options(
            enableCaching: true,
            coverage: .coverage(enabled: true, prefixMapping: true)
        ),
        cacheOptions: .options(profiles: .profiles(default: binaryCacheProfile))
    )
)
