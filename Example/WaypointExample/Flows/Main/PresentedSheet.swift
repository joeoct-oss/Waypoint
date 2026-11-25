//
//  PresentedSheet.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Observation
import Waypoint

// What draws the sheet a coordinator's router presents: which of its sheets it is, the presented
// router, and the sizes the router gives it. A coordinator keeps it once the present worked and
// releases it once SwiftUI's sheet has slid away, so the sheet still draws while it closes. Shop,
// Search and the accounts flow share it until Waypoint draws presentations itself (C3).
//
// Conformances:
// - `Observable` (from `@Observable`), so the sheet redraws when what it draws changes.
@Observable
final class PresentedSheet<Sheet> {
    // `var` because `keep(_:presentedBy:)` sets it and `release()` clears it.
    private(set) var sheet: Sheet?
    // `var` for the same reason as `sheet`: the presented sheet's router.
    private(set) var router: StackRouter?
    // `var` for the same reason as `sheet`: the sizes the presenting router gives the sheet.
    private(set) var options: SheetOptions?

    init() {
        sheet = nil
        router = nil
        options = nil
    }

    // Whether `presenter` presents this sheet now. Every tab shares one stack, so a sheet another
    // coordinator presents on it doesn't count.
    func isShowing(over presenter: StackRouter) -> Bool {
        guard let router else {
            return false
        }
        return presenter.presented === router
    }

    // Keeps what draws `sheet`, which `presenter` now presents. Does nothing when the present
    // didn't change what `presenter` presents.
    func keep(
        _ sheet: Sheet,
        presentedBy presenter: StackRouter
    ) {
        guard let presented = presenter.presented, presented !== router else {
            return
        }
        self.sheet = sheet
        router = presented
        options = presenter.state.presentation.map { presenter.sheetOptions(for: $0) }
    }

    func release() {
        sheet = nil
        router = nil
        options = nil
    }
}
