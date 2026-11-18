//
//  GuardedChangeTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Foundation
import Testing
import WaypointTestSupport

@testable import WaypointCore

/// Values change only through functions that guard the change ("`let` by default" in CONTRIBUTING).
@Suite("Guarded changes")
@MainActor
struct GuardedChangeTests {
    @Test
    func sheetOptionsAreAlwaysValid() {
        let noDetents: [SheetDetent] = []
        let large: [SheetDetent] = [.large]

        let options = SheetOptions(detents: noDetents, selectedDetent: .medium, fitsContentLimit: .fitsContent)

        #expect(options.detents == large)
        #expect(options.selectedDetent == nil)
        #expect(options.fitsContentLimit == .large)
    }

    @Test
    func sheetOptionsChangeThroughWithFunctions() {
        let base = SheetOptions.default
        let mediumAndLarge: [SheetDetent] = [.medium, .large]
        let large: [SheetDetent] = [.large]
        let changed = base
            .withDetents(mediumAndLarge, selected: .medium)
            .withFitsContentLimit(.medium)
            .withDragIndicator(true)
            .withInteractiveDismiss(false)

        #expect(base == .default)
        #expect(changed.detents == mediumAndLarge)
        #expect(changed.selectedDetent == .medium)
        #expect(changed.fitsContentLimit == .medium)
        #expect(changed.showsDragIndicator == true)
        #expect(!changed.allowsInteractiveDismiss)
        #expect(changed.withDetents(large).selectedDetent == nil)
    }

    @Test
    func decodedSheetOptionsAreChecked() throws {
        let json = Data(#"{"detents":[],"fitsContentLimit":{"fitsContent":{}},"allowsInteractiveDismiss":true}"#.utf8)

        let options = try JSONDecoder().decode(SheetOptions.self, from: json)

        #expect(options == SheetOptions())
    }

    @Test
    func tabStateKeepsSelectionInTabs() throws {
        let missing = TabState(tabs: MainTab.homeAndShop, selection: .profile)
        let noTabs: [MainTab] = []
        let shopOnly: [MainTab] = [.shop]
        let empty = TabState(tabs: noTabs, selection: MainTab.shop)
        let json = Data(#"{"tabs":["home","shop"],"selection":"profile"}"#.utf8)

        #expect(missing.selection == .home)
        #expect(empty.tabs == shopOnly)
        #expect(try JSONDecoder().decode(TabState<MainTab>.self, from: json).selection == .home)
    }

    @Test
    func logConfigurationChangesThroughWithFunctions() {
        let base = LogConfiguration.default
        let issuesOnly: Set<LogCategory> = [.issues]
        let changed = base
            .withMinimumLevel(.debug)
            .withCategories(issuesOnly)
            .withPrivateValuesRevealed(true)

        #expect(base.minimumLevel == .notice)
        #expect(changed.minimumLevel == .debug)
        #expect(changed.categories == issuesOnly)
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
        let expectedKinds: [NavigationIssue.Kind] = [.invalidSetting]
        #expect(reported.values == expectedKinds)
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
        let expectedKinds: [NavigationIssue.Kind] = [.invalidSetting]
        #expect(reported.values == expectedKinds)
    }
}
