//
//  UITestSteps.swift
//  WaypointExampleUITests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import XCTest

// The steps every UI test repeats: wait for an element, then use it. Each poll reads the app's
// whole accessibility tree, so polls are a quarter second apart, not faster.
enum UITestSteps {
    static let timeout: TimeInterval = 5
    static let pollInterval: TimeInterval = 0.25
    static let settleTime: TimeInterval = 1
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

    // Drags across the app's window, the way a person swipes back, slowly, because a fast drag can
    // cancel. The drag uses the window's coordinates, not the app's: on an iPad the window can
    // float in the middle of the screen, and the app's coordinates then point at the wallpaper.
    // iOS 17 ignores a drag that starts a few points in, so there it starts on the edge itself.
    // iOS 26 swipes back from anywhere in the content, and a drag on a floating window's edge
    // resizes the window, so there it starts a little in.
    @MainActor
    func swipeBack() {
        let window = windows.firstMatch
        let startX: CGFloat
        if #available(iOS 26, *) {
            startX = 0.1
        } else {
            startX = 0
        }
        let edge = window.coordinate(withNormalizedOffset: CGVector(dx: startX, dy: 0.5))
        let middle = window.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
        edge.press(
            forDuration: 0.05,
            thenDragTo: middle,
            withVelocity: .slow,
            thenHoldForDuration: 0
        )
    }

    // Lists build rows lazily, so a row below the fold exists only after scrolling to it. Waits for
    // the screen to finish sliding in before scrolling, so a row that was about to show is not
    // scrolled away, and scrolls back down for a row that ends up under the navigation bar.
    @MainActor
    func reveal(_ element: XCUIElement) -> Bool {
        _ = element.waitForExistence(timeout: UITestSteps.timeout)
        for _ in 0..<4 where !waitUntilTappable(element) {
            if isAboveVisibleArea(element) {
                swipeDown()
            } else {
                swipeUp()
            }
        }
        return waitUntilTappable(element)
    }

    // Polls for a short while, since a pushed screen's rows reach their place only once the push
    // ends, and says whether the element got there.
    @MainActor
    private func waitUntilTappable(_ element: XCUIElement) -> Bool {
        let deadline = Date().addingTimeInterval(UITestSteps.settleTime)
        while Date() < deadline {
            if isTappable(element) {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(UITestSteps.pollInterval))
        }
        return isTappable(element)
    }

    // Whether the element sits above the visible area, under the navigation bar, rather than below
    // it or not built yet.
    @MainActor
    private func isAboveVisibleArea(_ element: XCUIElement) -> Bool {
        guard element.exists, !element.frame.isEmpty else {
            return false
        }
        return element.frame.minY < visibleArea.minY
    }

    // Checks the frame alone and never asks `isHittable`, because `isHittable` fails the test
    // instead of returning false when XCTest finds no point to tap, as it does for a row while its
    // screen is still sliding in. A row counts once its whole frame is between the navigation bar
    // and the window's bottom edge. Every list this reveals sits on a pushed screen, which hides
    // the tab bar.
    @MainActor
    private func isTappable(_ element: XCUIElement) -> Bool {
        guard element.exists, !element.frame.isEmpty else {
            return false
        }
        return visibleArea.contains(element.frame)
    }

    // The part of the window below the navigation bar, where a row is not covered by anything.
    @MainActor
    private var visibleArea: CGRect {
        let window = windows.firstMatch.frame
        let navigationBar = navigationBars.firstMatch
        let top = navigationBar.exists ? max(window.minY, navigationBar.frame.maxY) : window.minY
        return CGRect(
            x: window.minX,
            y: top,
            width: window.width,
            height: max(0, window.maxY - top)
        )
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
