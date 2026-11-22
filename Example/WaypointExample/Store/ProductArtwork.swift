//
//  ProductArtwork.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// The illustration of a product, as the example app design canvas draws it. `ProductIllustration`
// draws each one, so the shop needs no image assets.
//
// Conformances:
// - `Hashable`, so a product that holds one stays hashable.
// - `CaseIterable`, so a preview can show every illustration.
nonisolated enum ProductArtwork: Hashable, CaseIterable {
    case orbitLamp
    case cometMug
    case nebulaThrow
    case starChartPrint
    case poleStarCandle
    case poleStarLamp

    // The two colors of the illustration's backdrop, from its top-left corner to its bottom-right
    // one.
    var backdrop: (start: UInt32, end: UInt32) {
        switch self {
        case .orbitLamp:
            return (0xE9EBFF, 0xFFE9D6)
        case .cometMug:
            return (0xFFE6F1, 0xE9EBFF)
        case .nebulaThrow:
            return (0xEFE6FF, 0xFFE3EE)
        case .starChartPrint:
            return (0xE3E7FF, 0xD9F1EA)
        case .poleStarCandle:
            return (0xFFF1DA, 0xFFE3EE)
        case .poleStarLamp:
            return (0xE2F2EC, 0xE9EBFF)
        }
    }
}
