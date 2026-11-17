//
//  KindChip.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// A small capsule that names a flow's kind in its color, shown in the navigation bar.
struct KindChip: View {
    let kind: FlowKind

    var body: some View {
        Text(kind.title)
            .font(Typography.label)
            .foregroundStyle(kind.tint.color)
            .padding(.horizontal, Spacing.small)
            .padding(.vertical, Spacing.extraSmall)
            .background(kind.subtleTint.color, in: Capsule())
    }
}
