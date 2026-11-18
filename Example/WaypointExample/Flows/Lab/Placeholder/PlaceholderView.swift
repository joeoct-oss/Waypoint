//
//  PlaceholderView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// The SwiftUI placeholder for a flow: its icon, name and summary, and a line naming the entry that
// opened it.
struct PlaceholderView: View {
    let entry: FlowEntry

    var body: some View {
        VStack(spacing: Spacing.large) {
            IconTile(
                symbolName: entry.flow.symbolName,
                size: Size.placeholderIcon,
                tint: entry.kind.tint,
                fill: entry.kind.subtleTint
            )
            Text(entry.flow.title)
                .font(Typography.display)
                .foregroundStyle(Palette.text.color)
            Text(entry.flow.summary)
                .font(Typography.body)
                .foregroundStyle(Palette.textSecondary.color)
            Text(entry.placeholderNote)
                .font(Typography.footnote)
                .foregroundStyle(Palette.textTertiary.color)
            Text(entry.placeholderLine)
                .font(Typography.code)
                .foregroundStyle(Palette.textSecondary.color)
        }
        .multilineTextAlignment(.center)
        .padding(Spacing.huge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background.color)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(Identifiers.placeholder(entry))
    }
}
