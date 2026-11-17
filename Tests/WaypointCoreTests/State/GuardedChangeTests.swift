//
//  GuardedChangeTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Foundation
import Testing
import WaypointTestSupport

@testable import WaypointCore

/// Values change only through functions that guard the change (decision 0014).
@Suite("Guarded changes")
@MainActor
struct GuardedChangeTests {
    @Test
    func sheetOptionsAreAlwaysValid() {
        let options = SheetOptions(detents: [], selectedDetent: .medium, fitsContentLimit: .fitsContent)

        #expect(options.detents == [.large])
        #expect(options.selectedDetent == nil)
        #expect(options.fitsContentLimit == .large)
    }

    @Test
    func sheetOptionsChangeThroughWithFunctions() {
        let base = SheetOptions.default
        let changed = base
            .withDetents([.medium, .large], selected: .medium)
            .withFitsContentLimit(.medium)
            .withDragIndicator(true)
            .withInteractiveDismiss(false)

        #expect(base == .default)
        #expect(changed.detents == [.medium, .large])
        #expect(changed.selectedDetent == .medium)
        #expect(changed.fitsContentLimit == .medium)
        #expect(changed.showsDragIndicator == true)
        #expect(!changed.allowsInteractiveDismiss)
        #expect(changed.withDetents([.large]).selectedDetent == nil)
    }

    @Test
    func decodedSheetOptionsAreChecked() throws {
        let json = Data(#"{"detents":[],"fitsContentLimit":{"fitsContent":{}},"allowsInteractiveDismiss":true}"#.utf8)

        let options = try JSONDecoder().decode(SheetOptions.self, from: json)

        #expect(options == SheetOptions())
    }

    @Test
    func tabStateKeepsSelectionInTabs() throws {
        let missing = TabState(tabs: [MainTab.home, .shop], selection: .profile)
        let empty = TabState(tabs: [], selection: MainTab.shop)
        let json = Data(#"{"tabs":["home","shop"],"selection":"profile"}"#.utf8)

        #expect(missing.selection == .home)
        #expect(empty.tabs == [.shop])
        #expect(try JSONDecoder().decode(TabState<MainTab>.self, from: json).selection == .home)
    }

    @Test
    func logConfigurationChangesThroughWithFunctions() {
        let base = LogConfiguration.default
        let changed = base
            .withMinimumLevel(.debug)
            .withCategories([.issues])
            .withPrivateValuesRevealed(true)

        #expect(base.minimumLevel == .notice)
        #expect(changed.minimumLevel == .debug)
        #expect(changed.categories == [.issues])
        #expect(changed.revealsPrivateValues)
    }

    @Test
    func fallbackPolicySetsAndClears() {
        let policy = FallbackPolicy().withFallback(.popToRoot, for: .emptyPath)

        #expect(policy[.emptyPath] == .popToRoot)
        #expect(policy.withFallback(nil, for: .emptyPath)[.emptyPath] == nil)
        #expect(FallbackPolicy()[.emptyPath] == nil)
    }

    @Test
    func registeringLeavesTheOriginalRegistryUnchanged() {
        let empty = RouteRegistry()
        let registry = empty.registering(HomeRoute.self)

        #expect(!empty.isRegistered(HomeRoute.self))
        #expect(registry.isRegistered(HomeRoute.self))
    }

    @Test
    func queueLimitBelowOneIsRefused() {
        let router = StackRouter()
        let reported = Recorder<NavigationIssue.Kind>()
        router.tree.onReported { issue in
            reported.record(issue.kind)
        }

        router.setMaxQueuedChanges(0)

        #expect(router.maxQueuedChanges == 32)
        #expect(reported.values == [.invalidSetting])
    }

    @Test
    func pushFallbackOnlySetsForRouteNotInPath() {
        let router = StackRouter()
        let reported = Recorder<NavigationIssue.Kind>()
        router.tree.onReported { issue in
            reported.record(issue.kind)
        }

        router.setFallback(.push, for: .emptyPath)
        router.setFallback(.push, for: .routeNotInPath)

        #expect(router.fallbackPolicy[.emptyPath] == nil)
        #expect(router.fallbackPolicy[.routeNotInPath] == .push)
        #expect(reported.values == [.invalidSetting])
    }
}
