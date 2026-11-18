//
//  FlowKind+Style.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// The color each kind wears: Nova (accent) for SwiftUI, Star line (brand) for UIKit.
extension FlowKind {
    var tint: ColorToken {
        switch self {
        case .swiftUI:
            return Palette.accent
        case .uiKit:
            return Palette.brand
        }
    }

    var subtleTint: ColorToken {
        switch self {
        case .swiftUI:
            return Palette.accentSubtle
        case .uiKit:
            return Palette.brandSubtle
        }
    }
}
