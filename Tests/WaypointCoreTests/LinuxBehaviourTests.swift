//
//  LinuxBehaviourTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Foundation
import Observation
import Testing

/// Pins the platform behaviour WaypointCore depends on, so a difference between Linux and Apple
/// platforms shows up here first instead of inside a router.
@Suite("Linux behaviour")
struct LinuxBehaviourTests {
    @Test
    func observationTrackingFiresOnChange() {
        let model = TrackedModel()
        let fired = FireCounter()

        withObservationTracking {
            _ = model.title
        } onChange: {
            fired.increment()
        }
        model.rename(to: "Changed")

        #expect(fired.calls == 1)
    }

    @Test
    func observationIgnoresUntrackedProperty() {
        let model = TrackedModel()
        let fired = FireCounter()

        withObservationTracking {
            _ = model.title
        } onChange: {
            fired.increment()
        }
        model.increment()

        #expect(fired.calls == 0)
    }

    @Test
    @MainActor
    func mainActorTestRunsOnMainActor() {
        let model = MainActorModel()

        model.push("detail")

        #expect(model.stack == ["detail"])
    }

    @Test
    func sendableValuesCrossActors() async {
        let value = SendableValue(id: 7, name: "detail")

        let returned = await Task.detached { value }.value

        #expect(returned == value)
    }
}
