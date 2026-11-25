//
//  AppSheets.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import WaypointCore

// How the app's sheets are shown, as Waypoint presentation styles, in one place. The main tab
// router sets `defaults` for the whole app with `setPresentationDefaults(_:)`, and a sheet
// presented with a bare `.sheet`, such as Reset password, takes them. The others choose their own:
//
// - The filters open at medium and grow to large.
// - Sign in and the wish list are large.
// - The saved sheet is just tall enough for its message and button.
// - The terms hide the drag indicator and can't be swiped away, so only Done closes them.
enum AppSheets {
    private static let mediumAndLarge: [SheetDetent] = [
        .medium,
        .large,
    ]
    private static let savedHeight: [SheetDetent] = [
        .height(240),
    ]

    static let defaults = PresentationDefaults(sheet: SheetOptions(
        detents: mediumAndLarge,
        selectedDetent: .medium,
        showsDragIndicator: true
    ))
    static let filters = PresentationStyle.sheet(
        detents: mediumAndLarge,
        selected: .medium
    )
    static let large = PresentationStyle.sheet(SheetOptions())
    static let saved = PresentationStyle.sheet(detents: savedHeight)
    static let terms = PresentationStyle.sheet(SheetOptions(
        showsDragIndicator: false,
        allowsInteractiveDismiss: false
    ))
}
