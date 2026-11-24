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
    // How many times `setSwitch(to:)` taps a switch before it gives up.
    static let maxTaps = 3
    static let accountTabTitle = "Account"
    // The identifier UIKit gives a navigation bar's Back button.
    static let backButtonID = "BackButton"
    // How long a step waits for iOS's offer to save a password after a sign in. iOS 27.2 offers
    // it about 4.5 seconds after the tap, and the step goes on as soon as it shows. iOS 17.5
    // never offers it, so there the step doesn't wait.
    static let savePasswordOfferTimeout: TimeInterval = 10
    // The newest major iOS version that never offers to save a password.
    static let lastVersionWithoutSavePasswordOffer = 17
    static var offersToSavePassword: Bool {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion > lastVersionWithoutSavePasswordOffer
    }
    // The offer's button that closes it without saving.
    static let savePasswordNotNow = "Not Now"
}

extension XCUIApplication {
    // Closes iOS's "Save Password?" offer when it shows after a sign in (planning #422). The offer
    // is the system's, not the app's, and it covers the app, so every tap after it misses until it
    // goes.
    @MainActor
    func closeSavePasswordOffer() {
        guard UITestSteps.offersToSavePassword else {
            return
        }
        let notNow = buttons[UITestSteps.savePasswordNotNow]
        guard notNow.waitForExistence(timeout: UITestSteps.savePasswordOfferTimeout) else {
            return
        }
        // A tap while the offer still fades in is lost, and the offer still covers the app while it
        // slides away. So the step taps only once the button takes taps, waits for the offer to go,
        // and taps again if it stayed, at most `maxTaps` times.
        for _ in 0..<UITestSteps.maxTaps {
            if notNow.waitUntilHittable() {
                notNow.tap()
            }
            if notNow.waitForNonExistence(timeout: UITestSteps.timeout) {
                return
            }
        }
        XCTFail("iOS's save password offer didn't close:\n\(debugDescription)")
    }
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

    // Flips the switch inside a toggle row until its value is `value` ("1" on, "0" off), and says
    // whether it got there. It taps the row's own switch, since a tap in the middle of the row may
    // land on its label. On iOS 17.5 the value can show the change a moment late, or a tap can
    // miss, so it waits up to `settleTime` after each tap and taps again, at most `maxTaps` times.
    @MainActor
    func setSwitch(to value: String) -> Bool {
        guard waitForExistence(timeout: UITestSteps.timeout) else {
            return false
        }
        for _ in 0..<UITestSteps.maxTaps {
            if self.value as? String == value {
                return true
            }
            switches.firstMatch.tap()
            if waitForValue(value) {
                return true
            }
        }
        return false
    }

    // Polls the element until it takes taps or `timeout` passes, and says whether it does.
    @MainActor
    func waitUntilHittable() -> Bool {
        let deadline = Date().addingTimeInterval(UITestSteps.timeout)
        while Date() < deadline {
            if exists && isHittable {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(UITestSteps.pollInterval))
        }
        return exists && isHittable
    }

    // Polls the element's value until it is `value` or `settleTime` passes.
    @MainActor
    private func waitForValue(_ value: String) -> Bool {
        let deadline = Date().addingTimeInterval(UITestSteps.settleTime)
        while Date() < deadline {
            if self.value as? String == value {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(UITestSteps.pollInterval))
        }
        return self.value as? String == value
    }
}

extension XCUIApplication {
    // Taps Back: the Back button of the first navigation bar a person can reach, found by its
    // identifier, or the bar's first button when it has none. On iOS 27 a bar's first button isn't
    // always Back. A sheet over a pushed screen leaves that screen's bar in the tree under it, and
    // the tabs share one stack, so the screen under the sheet can come first; its Back lies under
    // the sheet and can't be hit. Back can also report itself not hittable while it shows, so
    // when no Back is hittable, the first one that shows is tapped by its middle.
    @MainActor
    func goBack() {
        let backs = navigationBars.allElementsBoundByIndex.map { bar in
            let back = bar.buttons[UITestSteps.backButtonID]
            return back.exists ? back : bar.buttons.element(boundBy: 0)
        }
        if let reachable = backs.first(where: { $0.exists && $0.isHittable }) {
            reachable.tap()
            return
        }
        let shown = backs.first { $0.exists } ?? navigationBars.buttons.element(boundBy: 0)
        shown.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
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

    // Waits for the tab bar to show or hide, since SwiftUI hides it as a push starts and shows it
    // once a pop ends, and says whether it did in time.
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

    // Opens one of the Lab's tools from wherever the app is: Account, Settings, the Lab, then the
    // tool's row.
    @MainActor
    func openLabTool(_ tool: LabTool) {
        openTab(UITestSteps.accountTabTitle)
        buttons[Identifiers.settingsButton].tapWhenReady()
        buttons[Identifiers.labButton].tapWhenReady()
        let row = buttons[Identifiers.labTool(tool)]
        XCTAssertTrue(reveal(row), "missing \(Identifiers.labTool(tool))")
        row.tap()
    }
}
