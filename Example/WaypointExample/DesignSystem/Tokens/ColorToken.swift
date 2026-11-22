//
//  ColorToken.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import UIKit

// One color of the design system, with its light and dark values as 0xRRGGBB. Both renderers read
// the same token: SwiftUI through `color`, UIKit through `uiColor`, and both follow the system
// appearance.
nonisolated struct ColorToken {
    let light: UInt32
    let dark: UInt32

    var uiColor: UIColor {
        let lightColor = UIColor(hex: light)
        let darkColor = UIColor(hex: dark)
        return UIColor { $0.userInterfaceStyle == .dark ? darkColor : lightColor }
    }

    var color: Color {
        Color(uiColor: uiColor)
    }
}

nonisolated extension UIColor {
    convenience init(hex: UInt32) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}
