//
//  FlowRow.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// One flow in the SwiftUI branch: its icon, name and summary, and a button for each kind. The row reports
// the entry the reader picks.
struct FlowRow: View {
    let branch: Branch
    let flow: ExampleFlow
    let onSelect: (FlowEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            HStack(spacing: Spacing.medium) {
                icon
                titles
            }
            HStack(spacing: Spacing.small) {
                ForEach(FlowKind.allCases, id: \.self) { kind in
                    kindButton(for: kind)
                }
            }
            .padding(.leading, Size.rowIcon + Spacing.medium)
        }
        .padding(.horizontal, Spacing.medium + 2)
        .padding(.vertical, Spacing.medium)
    }

    private var icon: some View {
        IconTile(
            symbolName: flow.symbolName,
            size: Size.rowIcon,
            tint: Palette.brand,
            fill: Palette.brandSubtle
        )
    }

    private var titles: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(flow.title)
                .font(Typography.headline)
                .foregroundStyle(Palette.text.color)
            Text(flow.summary)
                .font(Typography.footnote)
                .foregroundStyle(Palette.textTertiary.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func kindButton(for kind: FlowKind) -> some View {
        let entry = FlowEntry(
            branch: branch,
            flow: flow,
            kind: kind
        )
        return Button(kind.buttonTitle) { onSelect(entry) }
            .buttonStyle(KindButtonStyle(kind: kind))
            .accessibilityIdentifier(Identifiers.entry(entry))
    }
}
