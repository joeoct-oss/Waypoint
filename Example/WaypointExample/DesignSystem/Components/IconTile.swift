//
//  IconTile.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// A rounded square holding an SF Symbol, used at the start of cards and rows.
package struct IconTile: View {
    package let symbolName: String
    package let size: CGFloat
    package let tint: ColorToken
    package let fill: ColorToken

    package init(
        symbolName: String,
        size: CGFloat,
        tint: ColorToken,
        fill: ColorToken
    ) {
        self.symbolName = symbolName
        self.size = size
        self.tint = tint
        self.fill = fill
    }

    package var body: some View {
        Image(systemName: symbolName)
            .font(.title3)
            .foregroundStyle(tint.color)
            .frame(width: size, height: size)
            .background(fill.color, in: RoundedRectangle(cornerRadius: Radius.field))
            .accessibilityHidden(true)
    }
}
