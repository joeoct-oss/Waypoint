//
//  SearchTests.swift
//  WaypointExampleUITests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import XCTest

// Search's results push from its view model (planning #417): a tapped result opens the product on
// the Search stack, and Back returns to the results, so the push went through the stack's router.
@MainActor
final class SearchTests: XCTestCase {
    private static let searchTitle = "Search"
    private static let lampTitle = "Orbit Lamp"
    private static let lampSearch = "lamp"
    private static let lampID = 1

    func testSearchResultOpensProduct() {
        let app = ExampleApp.launch()
        app.openTab(Self.searchTitle)
        app.buttons[Identifiers.recentSearch(Self.lampSearch)].tapWhenReady()
        let result = app.buttons[Identifiers.product(id: Self.lampID)]
        XCTAssertTrue(result.waitForExistence(timeout: UITestSteps.timeout), "the search found no lamp")
        result.tap()

        XCTAssertTrue(app.navigationBars[Self.lampTitle].waitForExistence(timeout: UITestSteps.timeout))
        app.goBack()
        XCTAssertTrue(result.waitForExistence(timeout: UITestSteps.timeout), "Back didn't return to the results")
    }
}
