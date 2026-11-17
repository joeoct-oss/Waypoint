import XCTest

/// Spike A, the documented gap: a container inside the host app's own stack, with `-adapt`.
final class ContainerAdaptTests: XCTestCase {
    private func run(host: String, renderer: String) {
        let app = launch(["-scenario", "a", "-host", host, "-renderer", renderer, "-adapt"])
        let tag = "A-adapt-\(host)-\(renderer)"
        tap(app, "openFlow")
        sleep(1)
        finding("\(tag) root: \(navigationBarSummary(app)) exit=\(app.buttons["container.exit"].exists)")
        shot("\(tag)-1-root")
        tap(app, "pushProduct")
        sleep(1)
        finding("\(tag) pushed: \(navigationBarSummary(app)) state=\(state(app))")
        shot("\(tag)-2-pushed")
        swipeBack(app)
        finding("\(tag) swipe back: \(navigationBarSummary(app)) state=\(state(app))")
        // At the container's root, swipe back should leave the container for the host.
        swipeBack(app)
        sleep(1)
        finding("\(tag) swipe back at root: openFlow visible=\(app.buttons["openFlow"].exists) \(navigationBarSummary(app))")
        if !app.buttons["openFlow"].exists, app.buttons["container.exit"].exists {
            app.buttons["container.exit"].tap()
            sleep(1)
            finding("\(tag) exit button: openFlow visible=\(app.buttons["openFlow"].exists) \(navigationBarSummary(app))")
        }
        shot("\(tag)-3-after-exit")
    }

    func testForeignNavSwiftUI() { run(host: "foreignNav", renderer: "swiftUI") }
    func testForeignNavUIKit() { run(host: "foreignNav", renderer: "uiKit") }
    func testSwiftUINestedSwiftUI() { run(host: "swiftuiNested", renderer: "swiftUI") }
    func testSwiftUINestedUIKit() { run(host: "swiftuiNested", renderer: "uiKit") }
}
