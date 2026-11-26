//
//  ExampleApp.swift
//  WaypointExampleUITests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import XCTest

// Launches the example app for a UI test, always from a fresh install: as a guest, signed in, or
// straight into the Navigation Lab, one of its branches or one of its twenty entries. The splash is
// skipped, which saves a second on every launch, unless a test holds it up to see it. `systemLinks`
// draws the product page's related link as a system `NavigationLink`, and `missingDestination`
// makes it push a route with no destination in its stack.
//
// Animations run three times as fast, so each step settles sooner (planning #489). A test whose
// promise depends on an animation's real length passes `animationSpeed: .real`, with a comment
// saying why. This is the one list of those tests:
// - StackTests: testDoubleTapPushesOnce, testSwipeBackReachesRouter, testPopMidTransition,
//   testPopToRootMidTransition and testLinkMidTransition, which act while a push or pop is still
//   moving, or rely on a gesture's timing.
// - LabSheetTests: testLabSheetCoverOpensAndCloses and testLabSheetPresentsRightAfterDismiss,
//   which present while a sheet or cover still slides.
// - SheetTests: testFiltersSheetUsesItsDetents, which drags the sheet between its sizes.
enum ExampleApp {
    // How fast the app's animations run during a test.
    enum AnimationSpeed {
        // Three times as fast, which every test uses unless it needs real timing.
        case fast
        // The usual speed, for the tests listed above.
        case real

        var launchValue: String? {
            switch self {
            case .fast:
                "3"
            case .real:
                nil
            }
        }
    }

    private static let yes = "YES"

    @MainActor
    static func launch(
        signedIn: Bool = false,
        lab: Bool = false,
        branch: Branch? = nil,
        flow: ExampleFlow? = nil,
        kind: FlowKind? = nil,
        splashSeconds: Int = 0,
        shopPath: [Int] = [],
        shopFollowUp: ShopFollowUp? = nil,
        systemLinks: Bool = false,
        missingDestination: Bool = false,
        labReviewsSeconds: Int? = nil,
        animationSpeed: AnimationSpeed = .fast
    ) -> XCUIApplication {
        // A fresh launch has no offer from an earlier test's sign in.
        UITestSteps.savePasswordOfferMayCome = false
        let app = XCUIApplication()
        app.launchArguments = arguments(
            signedIn: signedIn,
            lab: lab,
            branch: branch,
            flow: flow,
            kind: kind,
            splashSeconds: splashSeconds,
            shopPath: shopPath,
            shopFollowUp: shopFollowUp,
            systemLinks: systemLinks,
            missingDestination: missingDestination,
            labReviewsSeconds: labReviewsSeconds,
            animationSpeed: animationSpeed
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
        splashSeconds: Int,
        shopPath: [Int],
        shopFollowUp: ShopFollowUp?,
        systemLinks: Bool,
        missingDestination: Bool,
        labReviewsSeconds: Int?,
        animationSpeed: AnimationSpeed
    ) -> [String] {
        let path = shopPath.isEmpty ? nil : shopPath.map(String.init).joined(separator: ",")
        let values: [(LaunchArgument, String?)] = [
            (LaunchArgument.clearData, yes),
            (LaunchArgument.signedIn, signedIn ? yes : nil),
            (LaunchArgument.lab, lab ? yes : nil),
            (LaunchArgument.branch, branch?.rawValue),
            (LaunchArgument.flow, flow?.rawValue),
            (LaunchArgument.kind, kind?.rawValue),
            (LaunchArgument.splashSeconds, String(splashSeconds)),
            (LaunchArgument.shopPath, path),
            (LaunchArgument.shopFollowUp, shopFollowUp?.rawValue),
            (LaunchArgument.systemLinks, systemLinks ? yes : nil),
            (LaunchArgument.missingDestination, missingDestination ? yes : nil),
            (LaunchArgument.labReviewsSeconds, labReviewsSeconds.map(String.init)),
            (LaunchArgument.animationSpeed, animationSpeed.launchValue),
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
