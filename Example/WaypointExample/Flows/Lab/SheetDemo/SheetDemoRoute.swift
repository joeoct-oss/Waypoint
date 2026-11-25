//
//  SheetDemoRoute.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import WaypointCore

// A level of the Sheet story: the root of each sheet or cover the story presents, numbered from 1
// above the story's own screen.
//
// Conformances:
// - `TrackableScreen`, a `Route` the journey log names "Sheet level", with its number public.
package struct SheetDemoRoute: TrackableScreen {
    package static let screenName = "Sheet level"
    package static let publicLogFields: Set<String> = [
        "level",
    ]

    package let level: Int
}

// The size the Sheet story gives the next sheet.
//
// Conformances:
// - `CaseIterable`, so the size picker lists every size.
// - `Hashable`, so the picker can select one.
package enum SheetDemoSize: CaseIterable, Hashable {
    case medium
    case large
    case fitsContent

    private static let mediumDetents = [
        SheetDetent.medium,
    ]
    private static let largeDetents = [
        SheetDetent.large,
    ]
    private static let fitsContentDetents = [
        SheetDetent.fitsContent,
    ]

    package var title: String {
        switch self {
        case .medium:
            return "Medium"
        case .large:
            return "Large"
        case .fitsContent:
            return "Fits"
        }
    }

    package var detents: [SheetDetent] {
        switch self {
        case .medium:
            return Self.mediumDetents
        case .large:
            return Self.largeDetents
        case .fitsContent:
            return Self.fitsContentDetents
        }
    }
}

// A sheet or cover the Sheet story presented: its router, the router that presented it, its number
// and the sizes the presenting router gave it.
package struct SheetDemoLevel {
    package let router: StackRouter
    package let presenter: StackRouter
    package let number: Int
    package let options: SheetOptions?
}
