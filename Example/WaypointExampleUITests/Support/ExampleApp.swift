//
//  ExampleApp.swift
//  WaypointExampleUITests
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import XCTest

// Launches the example app for a UI test, optionally straight onto a branch or one of the twenty entries.
enum ExampleApp {
    @MainActor
    static func launch(
        branch: Branch? = nil,
        flow: ExampleFlow? = nil,
        kind: FlowKind? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments(
            branch: branch,
            flow: flow,
            kind: kind
        )
        app.launch()
        return app
    }

    private static func arguments(
        branch: Branch?,
        flow: ExampleFlow?,
        kind: FlowKind?
    ) -> [String] {
        let values = [
            (LaunchArgument.branch, branch?.rawValue),
            (LaunchArgument.flow, flow?.rawValue),
            (LaunchArgument.kind, kind?.rawValue),
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
