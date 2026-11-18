//
//  IconTile.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// A rounded square holding an SF Symbol, used at the start of cards and rows.
struct IconTile: View {
    let symbolName: String
    let size: CGFloat
    let tint: ColorToken
    let fill: ColorToken

    var body: some View {
        Image(systemName: symbolName)
            .font(.title3)
            .foregroundStyle(tint.color)
            .frame(width: size, height: size)
            .background(fill.color, in: RoundedRectangle(cornerRadius: Radius.field))
            .accessibilityHidden(true)
    }
}
