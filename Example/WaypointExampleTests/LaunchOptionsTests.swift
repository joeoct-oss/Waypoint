//
//  LaunchOptionsTests.swift
//  WaypointExampleTests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCatalog
import ExampleNavigation
import ExampleTestSupport
import Foundation
import Testing

// The animation speed launch option (planning #489): UI tests ask for faster animations with
// `-animationSpeed`, and anything else keeps the usual speed, so a plain launch never changes how
// the app moves.
struct LaunchOptionsTests {
    @Test("A plain launch runs animations at the usual speed")
    func plainLaunchKeepsTheUsualSpeed() {
        let options = launchOptions(animationSpeed: nil)

        #expect(options.animationSpeed == 1)
    }

    @Test("An animation speed of 3 runs animations three times as fast")
    func animationSpeedIsRead() {
        let options = launchOptions(animationSpeed: "3")

        #expect(options.animationSpeed == 3)
    }

    @Test(
        "An animation speed of 0 or less keeps the usual speed",
        arguments: ["0", "-2"]
    )
    func animationSpeedOfZeroOrLessKeepsTheUsualSpeed(value: String) {
        let options = launchOptions(animationSpeed: value)

        #expect(options.animationSpeed == 1)
    }

    @Test("Starting over after Clear all data keeps the animation speed")
    func startingOverKeepsTheAnimationSpeed() {
        let options = launchOptions(animationSpeed: "3")

        #expect(options.startingOver().animationSpeed == 3)
    }

    // The options a launch reads, from a fresh domain holding only the animation speed, as
    // `UserDefaults` parses it from `-animationSpeed <value>`.
    private func launchOptions(animationSpeed: String?) -> LaunchOptions {
        let domain = TestStore.domainPrefix + UUID().uuidString
        let defaults = UserDefaults(suiteName: domain) ?? .standard
        defaults.set(animationSpeed, forKey: LaunchArgument.animationSpeed.rawValue)
        let options = LaunchOptions(defaults: defaults)
        defaults.removePersistentDomain(forName: domain)
        return options
    }
}
