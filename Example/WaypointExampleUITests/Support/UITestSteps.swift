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

    // Turns on the switch inside a toggle row. Tapping the row's middle can land on its label, which does
    // nothing.
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

    // Lists build rows lazily, so a row below the fold exists only after scrolling to it.
    @MainActor
    func reveal(_ element: XCUIElement) -> Bool {
        _ = element.waitForExistence(timeout: UITestSteps.timeout)
        for _ in 0..<4 where !isTappable(element) {
            swipeUp()
        }
        return isTappable(element)
    }

    // Checks the frame before asking `isHittable`, because a button that exists while its screen is still
    // being pushed has no frame yet, and `isHittable` then fails the test instead of returning false.
    @MainActor
    private func isTappable(_ element: XCUIElement) -> Bool {
        element.exists && !element.frame.isEmpty && element.isHittable
    }

    // Opens a main tab by its title.
    @MainActor
    func openTab(_ title: String) {
        tabBars.buttons[title].tapWhenReady()
    }
}
