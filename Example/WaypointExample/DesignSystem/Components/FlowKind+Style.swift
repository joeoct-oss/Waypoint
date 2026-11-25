//
//  FlowKind+Style.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCatalog

// The color each kind wears: Nova (accent) for SwiftUI, Star line (brand) for UIKit.
extension FlowKind {
    package var tint: ColorToken {
        switch self {
        case .swiftUI:
            return Palette.accent
        case .uiKit:
            return Palette.brand
        }
    }

    package var subtleTint: ColorToken {
        switch self {
        case .swiftUI:
            return Palette.accentSubtle
        case .uiKit:
            return Palette.brandSubtle
        }
    }
}
