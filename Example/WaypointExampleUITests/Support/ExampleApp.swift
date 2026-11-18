//
//  ExampleApp.swift
//  WaypointExampleUITests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import XCTest

// Launches the example app for a UI test, always from a fresh install: as a guest from the splash
// (held longer when a test needs to see it), signed in, or straight into the Navigation Lab, one of
// its branches or one of its twenty entries.
enum ExampleApp {
    private static let yes = "YES"

    @MainActor
    static func launch(
        signedIn: Bool = false,
        lab: Bool = false,
        branch: Branch? = nil,
        flow: ExampleFlow? = nil,
        kind: FlowKind? = nil,
        splashSeconds: Int? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments(
            signedIn: signedIn,
            lab: lab,
            branch: branch,
            flow: flow,
            kind: kind,
            splashSeconds: splashSeconds
        )
        app.launch()
        return app
    }

    private static func arguments(
        signedIn: Bool,
        lab: Bool,
        branch: Branch?,
        flow: ExampleFlow?,
        kind: FlowKind?,
        splashSeconds: Int?
    ) -> [String] {
        let values: [(LaunchArgument, String?)] = [
            (LaunchArgument.clearData, yes),
            (LaunchArgument.signedIn, signedIn ? yes : nil),
            (LaunchArgument.lab, lab ? yes : nil),
            (LaunchArgument.branch, branch?.rawValue),
            (LaunchArgument.flow, flow?.rawValue),
            (LaunchArgument.kind, kind?.rawValue),
            (LaunchArgument.splashSeconds, splashSeconds.map(String.init)),
        ]
        return values.flatMap { argumentPair($0.0, $0.1) }
    }

    private static func argumentPair(
        _ argument: LaunchArgument,
        _ value: String?
    ) -> [String] {
        guard let value else {
            return []
        }
        return [argument.flag, value]
    }
}
