//
//  SheetTests.swift
//  WaypointExampleUITests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import XCTest

// The app's sheets take their sizes and swipe-to-close from Waypoint's `SheetOptions`
// (planning #412): the filters are presented with their own sizes, which the event log shows, a
// bare `.sheet` takes the app's defaults and can grow to large, and the terms can't be swiped away.
// A sheet's size is read from where its navigation bar sits on the screen.
@MainActor
final class SheetTests: XCTestCase {
    private static let accountTitle = "Account"
    private static let filterTitle = "Filter"
    private static let resetTitle = "Reset password"
    private static let signUpName = "Nova Reader"
    private static let email = "nova@example.com"
    private static let password = "orbit-2026"
    // A medium sheet's top sits below this share of the screen, and a large one's above the next.
    private static let mediumTopShare: CGFloat = 0.35
    private static let largeTopShare: CGFloat = 0.25
    private static let pollInterval: TimeInterval = 0.25
    // A drag to large starts this far above the sheet's navigation bar, on its grabber, and ends
    // at this share of the screen's height.
    private static let grabberOffset: CGFloat = -12
    private static let dragEndShare: CGFloat = 0.08
    private static let dragPress: TimeInterval = 0.1
    // How long a drag waits for the sheet to settle at large before it drags again.
    private static let settleTimeout: TimeInterval = 2
    // How the event log writes the filters' presentation, with the sizes the router gave it.
    private static let filterPresentation = NSPredicate(format: "label CONTAINS 'detents: [medium, large]'")

    func testFiltersSheetUsesItsDetents() {
        let app = ExampleApp.launch()
        app.buttons[Identifiers.filterButton].tapWhenReady()

        let bar = app.navigationBars[Self.filterTitle]
        XCTAssertTrue(bar.waitForExistence(timeout: UITestSteps.timeout))
        XCTAssertTrue(waitForTop(of: bar, below: Self.mediumTopShare, in: app), "the filters didn't open at medium")

        XCTAssertTrue(growToLarge(bar, in: app), "the filters didn't grow to large")
        app.buttons[Identifiers.filterApply].tapWhenReady()
        XCTAssertTrue(bar.waitForNonExistence(timeout: UITestSteps.timeout))

        app.openLabTool(.eventLog)
        let entry = app.descendants(matching: .any).matching(Self.filterPresentation).firstMatch
        XCTAssertTrue(app.reveal(entry), "the event log doesn't show the filters' own sizes")
    }

    func testBareSheetUsesAppDefaults() {
        let app = ExampleApp.launch()
        app.openTab(Self.accountTitle)
        app.buttons[Identifiers.accountSignIn].tapWhenReady()
        app.buttons[Identifiers.forgotPassword].tapWhenReady()

        let bar = app.navigationBars[Self.resetTitle]
        XCTAssertTrue(bar.waitForExistence(timeout: UITestSteps.timeout))
        let isMedium = waitForTop(of: bar, below: Self.mediumTopShare, in: app)
        XCTAssertTrue(isMedium, "Reset password didn't open at the app's default medium")
        let isLarge = growToLarge(bar, in: app)
        XCTAssertTrue(isLarge, "Reset password can't grow to the app's default large")
    }

    func testLockedSheetIgnoresSwipe() {
        let app = ExampleApp.launch()
        app.openTab(Self.accountTitle)
        app.buttons[Identifiers.accountSignIn].tapWhenReady()
        app.buttons[Identifiers.signInCreateAccount].tapWhenReady()
        app.textFields[Identifiers.signUpName].type(Self.signUpName)
        app.textFields[Identifiers.signUpEmail].type(Self.email)
        app.buttons[Identifiers.signUpContinue].tapWhenReady()
        app.secureTextFields[Identifiers.signUpPassword].type(Self.password)
        app.buttons[Identifiers.signUpTerms].tapWhenReady()

        let terms = app.descendants(matching: .any)[Identifiers.terms]
        XCTAssertTrue(terms.waitForExistence(timeout: UITestSteps.timeout))
        terms.swipeDown(velocity: .fast)
        XCTAssertFalse(terms.waitForNonExistence(timeout: UITestSteps.timeout), "a swipe closed the terms")

        app.buttons[Identifiers.termsDone].tapWhenReady()
        XCTAssertTrue(terms.waitForNonExistence(timeout: UITestSteps.timeout), "Done didn't close the terms")
    }

    private func waitForTop(
        of element: XCUIElement,
        below share: CGFloat,
        in app: XCUIApplication
    ) -> Bool {
        waitUntil { element.frame.minY > app.frame.height * share }
    }

    private func waitForTop(
        of element: XCUIElement,
        above share: CGFloat,
        in app: XCUIApplication,
        timeout: TimeInterval = UITestSteps.timeout
    ) -> Bool {
        waitUntil(timeout: timeout) { element.frame.minY < app.frame.height * share }
    }

    // Drags a medium sheet up by its grabber until its top sits above `largeTopShare`, at most
    // `maxTaps` times, and says whether it got there (planning #426). On iOS 27.2 one `swipeUp()`
    // on the sheet's navigation bar often leaves the sheet at medium, since the bar takes the
    // swipe.
    private func growToLarge(
        _ bar: XCUIElement,
        in app: XCUIApplication
    ) -> Bool {
        for _ in 0..<UITestSteps.maxTaps {
            let grabber = bar
                .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0))
                .withOffset(CGVector(dx: 0, dy: Self.grabberOffset))
            let top = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: Self.dragEndShare))
            grabber.press(forDuration: Self.dragPress, thenDragTo: top)
            if waitForTop(of: bar, above: Self.largeTopShare, in: app, timeout: Self.settleTimeout) {
                return true
            }
        }
        return false
    }

    // Polls by hand, because a sheet settles faster than an expectation's one-second poll.
    private func waitUntil(
        timeout: TimeInterval = UITestSteps.timeout,
        _ condition: () -> Bool
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(Self.pollInterval))
        }
        return condition()
    }
}
