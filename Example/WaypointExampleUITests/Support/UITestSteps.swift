//
//  UITestSteps.swift
//  WaypointExampleUITests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import XCTest

// The steps every UI test repeats: wait for an element, then use it.
enum UITestSteps {
    static let timeout: TimeInterval = 5
    static let pollInterval: TimeInterval = 0.1
}

extension XCUIElement {
    // Waits for the element, fails the test if it never shows, and taps it.
    @MainActor
    func tapWhenReady(
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            waitForExistence(timeout: UITestSteps.timeout),
            "missing \(identifier)",
            file: file,
            line: line
        )
        tap()
    }

    // Taps the element and types into it.
    @MainActor
    func type(_ text: String) {
        tapWhenReady()
        typeText(text)
    }

    // Turns on the switch inside a toggle row. Tapping the row's middle can land on its label,
    // which does nothing.
    @MainActor
    func turnOn() {
        XCTAssertTrue(waitForExistence(timeout: UITestSteps.timeout))
        switches.firstMatch.tap()
    }
}

extension XCUIApplication {
    // Taps the first button in the navigation bar, which is Back on a pushed screen.
    @MainActor
    func goBack() {
        navigationBars.buttons.element(boundBy: 0).tap()
    }

    // Drags from the screen's left edge, the way a person swipes back. The drag starts on the edge
    // itself and moves slowly, because iOS 17 ignores a drag that starts a few points in, and a
    // fast drag can cancel.
    @MainActor
    func swipeBack() {
        let edge = coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
        let middle = coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
        edge.press(
            forDuration: 0.05,
            thenDragTo: middle,
            withVelocity: .slow,
            thenHoldForDuration: 0
        )
    }

    // Lists build rows lazily, so a row below the fold exists only after scrolling to it.
    @MainActor
    func reveal(_ element: XCUIElement) -> Bool {
        _ = element.waitForExistence(timeout: UITestSteps.timeout)
        for _ in 0..<4 where !isTappable(element) {
            swipeUp()
        }
        return isTappable(element)
    }

    // Checks the frame before asking `isHittable`, because a button that exists while its screen is
    // still being pushed has no frame yet, and a row cut off by the bottom edge has no point to tap:
    // `isHittable` then fails the test instead of returning false. A row only counts once its
    // whole frame is inside the window.
    @MainActor
    private func isTappable(_ element: XCUIElement) -> Bool {
        guard element.exists, !element.frame.isEmpty else {
            return false
        }
        let window = windows.firstMatch.frame
        return window.contains(element.frame) && element.isHittable
    }

    // Whether the main tab bar is on screen. A hidden tab bar can stay in the tree off screen, so
    // this checks that it can be tapped.
    @MainActor
    var isTabBarShown: Bool {
        let tabBar = tabBars.firstMatch
        return tabBar.exists && !tabBar.frame.isEmpty && tabBar.isHittable
    }

    // Waits for the tab bar to show or hide, since it slides with the push or pop, and says whether
    // it did in time.
    @MainActor
    func waitForTabBar(shown: Bool) -> Bool {
        let deadline = Date().addingTimeInterval(UITestSteps.timeout)
        while Date() < deadline {
            if isTabBarShown == shown {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(UITestSteps.pollInterval))
        }
        return isTabBarShown == shown
    }

    // Opens a main tab by its title.
    @MainActor
    func openTab(_ title: String) {
        tabBars.buttons[title].tapWhenReady()
    }
}
