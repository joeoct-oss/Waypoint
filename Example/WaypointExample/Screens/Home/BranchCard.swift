//
//  BranchCard.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// A card on Home for one branch: its icon in the host kind's color, its name, what hosts it, and the
// flows it can launch.
struct BranchCard: View {
    let branch: Branch
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            content
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(Identifiers.branch(branch))
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            HStack(spacing: Spacing.medium) {
                icon
                titles
                Image(systemName: "chevron.right")
                    .foregroundStyle(Palette.textTertiary.color)
            }
            Text(flowNames)
                .font(Typography.footnote)
                .foregroundStyle(Palette.textSecondary.color)
        }
        .padding(Spacing.large + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var icon: some View {
        IconTile(
            symbolName: branch.symbolName,
            size: Size.cardIcon,
            tint: branch.hostKind.tint,
            fill: branch.hostKind.subtleTint
        )
    }

    private var titles: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(branch.title)
                .font(Typography.title)
                .foregroundStyle(Palette.text.color)
            Text(branch.summary)
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
