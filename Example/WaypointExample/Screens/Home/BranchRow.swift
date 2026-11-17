//
//  BranchRow.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// A row on Home for one branch: its icon in the host kind's color, its name, what hosts it, and the flows
// it can launch.
struct BranchRow: View {
    let branch: Branch
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            content
        }
        .foregroundStyle(Palette.text.color)
        .accessibilityIdentifier(Identifiers.branch(branch))
    }

    private var content: some View {
        HStack(spacing: Spacing.medium) {
            IconTile(
                symbolName: branch.symbolName,
                size: Size.cardIcon,
                tint: branch.hostKind.tint,
                fill: branch.hostKind.subtleTint
            )
            titles
            Image(systemName: "chevron.right")
                .font(Typography.footnote.weight(.semibold))
                .foregroundStyle(Palette.textTertiary.color)
        }
        .padding(.vertical, Spacing.small)
    }

    private var titles: some View {
        VStack(alignment: .leading, spacing: Spacing.extraSmall) {
            Text(branch.title)
                .font(Typography.headline)
            Text(branch.summary)
                .font(Typography.footnote)
                .foregroundStyle(Palette.textSecondary.color)
            Text(flowNames)
                .font(Typography.footnote)
                .foregroundStyle(Palette.textTertiary.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var flowNames: String {
        ExampleFlow.allCases
            .map(\.title)
            .joined(separator: " · ")
    }
}
