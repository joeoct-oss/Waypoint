//
//  KindChip.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Names a flow's kind in its color in the navigation bar. From iOS 26 the bar draws the item in glass, so
// the chip adds no shape of its own; earlier systems get a tinted capsule.
struct KindChip: View {
    let kind: FlowKind

    var body: some View {
        if #available(iOS 26.0, *) {
            label
        } else {
            capsule
        }
    }

    private var label: some View {
        Text(kind.title)
            .font(Typography.label)
            .foregroundStyle(kind.tint.color)
    }

    private var capsule: some View {
        label
            .padding(.horizontal, Spacing.small)
            .padding(.vertical, Spacing.extraSmall)
            .background(kind.subtleTint.color, in: Capsule())
    }
}
