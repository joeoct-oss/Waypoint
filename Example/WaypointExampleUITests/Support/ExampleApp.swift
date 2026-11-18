//
//  ExampleApp.swift
//  WaypointExampleUITests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import XCTest

// Launches the example app for a UI test: from the splash (held longer when a test needs to see it),
// signed in, as a guest, or straight into the Navigation Lab, one of its branches or one of its twenty
// entries.
enum ExampleApp {
    private static let yes = "YES"

    @MainActor
    static func launch(
        signedIn: Bool = false,
        guest: Bool = false,
        lab: Bool = false,
        branch: Branch? = nil,
        flow: ExampleFlow? = nil,
        kind: FlowKind? = nil,
        splashSeconds: Int? = nil,
        shopPath: [Int] = [],
        shopFollowUp: ShopFollowUp? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments(
            signedIn: signedIn,
            guest: guest,
            lab: lab,
            branch: branch,
            flow: flow,
            kind: kind,
            splashSeconds: splashSeconds,
            shopPath: shopPath,
            shopFollowUp: shopFollowUp
        )
        app.launch()
        return app
    }

    private static func arguments(
        signedIn: Bool,
        guest: Bool,
        lab: Bool,
        branch: Branch?,
        flow: ExampleFlow?,
        kind: FlowKind?,
        splashSeconds: Int?,
        shopPath: [Int],
        shopFollowUp: ShopFollowUp?
    ) -> [String] {
        let path = shopPath.isEmpty ? nil : shopPath.map(String.init).joined(separator: ",")
        let values = [
            (LaunchArgument.signedIn, signedIn ? yes : nil),
            (LaunchArgument.guest, guest ? yes : nil),
            (LaunchArgument.lab, lab ? yes : nil),
            (LaunchArgument.branch, branch?.rawValue),
            (LaunchArgument.flow, flow?.rawValue),
            (LaunchArgument.kind, kind?.rawValue),
            (LaunchArgument.splashSeconds, splashSeconds.map(String.init)),
            (LaunchArgument.shopPath, path),
            (LaunchArgument.shopFollowUp, shopFollowUp?.rawValue),
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
