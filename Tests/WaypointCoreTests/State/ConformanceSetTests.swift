//
//  ConformanceSetTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import WaypointTestSupport

@testable import WaypointCore

/// The named conformance sets (see the "Why these conformances" article): each type has the set its
/// documentation names.
@Suite("Conformance sets")
struct ConformanceSetTests {
    @Test("Route and state value types are navigation values")
    func valuesAreNavigationValues() {
        #expect(isNavigationValue(FlowID.self))
        #expect(isNavigationValue(RouteKey.self))
        #expect(isNavigationValue(AnyRoute.self))
        #expect(isNavigationValue(PresentationStyle.self))
        #expect(isNavigationValue(SheetOptions.self))
        #expect(isNavigationValue(SheetDetent.self))
        #expect(isNavigationValue(ProductRoute.self))
        #expect(isNavigationValue(MainTab.self))
    }

    @Test("Reported values are navigation records")
    func reportedValuesAreNavigationRecords() {
        #expect(isNavigationRecord(NavigationChange.self))
        #expect(isNavigationRecord(NavigationOutcome.self))
        #expect(isNavigationRecord(NavigationIssue.self))
        #expect(isNavigationRecord(NavigationFailure.self))
        #expect(isNavigationRecord(NavigationFallback.self))
        #expect(isNavigationRecord(RouteDecodingError.self))
    }

    @Test("State values are navigation state values")
    func stateValuesAreSavedRecords() {
        #expect(isNavigationStateValue(StackState.self))
        #expect(isNavigationStateValue(TabState<MainTab>.self))
        #expect(isNavigationStateValue(Presentation.self))
        #expect(isNavigationStateValue(NavigationTree.self))
    }

    // Compiles only for a `NavigationValue`, so a missing part fails the build.
    private func isNavigationValue<T: NavigationValue>(_ type: T.Type) -> Bool {
        true
    }

    // Compiles only for a `NavigationRecord`.
    private func isNavigationRecord<T: NavigationRecord>(_ type: T.Type) -> Bool {
        true
    }

    // Compiles only for a `NavigationStateValue`.
    private func isNavigationStateValue<T: NavigationStateValue>(_ type: T.Type) -> Bool {
        true
    }
}
