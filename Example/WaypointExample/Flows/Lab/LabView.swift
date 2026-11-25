//
//  LabView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCatalog
import ExampleDesignSystem
import SwiftUI

// The Navigation Lab: one row per branch, each opening the five demo flows in both kinds, one row
// per story of the Views and view models epic, then the Lab tools (the navigation tree and the
// event log, with its count). The screen reports the branch, story or tool the reader picks, and
// the account coordinator opens it. The bar already shows the Lab's name, so the
// list's header shows only its slogan.
struct LabView: View {
    let onSelectBranch: (Branch) -> Void
    let onSelectStory: (ViewModelStory) -> Void
    let eventCount: Int
    let onSelectTool: (LabTool) -> Void

    var body: some View {
        List {
            Section {
                ForEach(Branch.allCases, id: \.self) { branch in
                    BranchRow(branch: branch) { onSelectBranch(branch) }
                }
            } header: {
                header
            }
            Section("Views and view models") {
                ForEach(ViewModelStory.allCases, id: \.self) { story in
                    makeStoryRow(for: story)
                }
            }
            Section("Lab tools") {
                ForEach(LabTool.allCases, id: \.self) { tool in
                    makeToolRow(for: tool)
                }
            }
        }
        .exampleList()
        .accessibilityIdentifier(Identifiers.lab)
    }

    private var header: some View {
        slogan
            .textCase(nil)
            .padding(.bottom, Spacing.small)
            .accessibilityElement(children: .combine)
    }

    private var slogan: some View {
        VStack(alignment: .leading, spacing: Spacing.extraSmall) {
            HStack(spacing: Spacing.extraSmall) {
                Text("Try every flow")
                    .foregroundStyle(Palette.textSecondary.color)
                Text("in SwiftUI and UIKit.")
                    .fontWeight(.semibold)
                    .foregroundStyle(Palette.accent.color)
            }
            Text("Know every route.")
                .fontWeight(.semibold)
                .foregroundStyle(Palette.brand.color)
        }
        .font(Typography.callout)
    }

    private func makeStoryRow(for story: ViewModelStory) -> some View {
        Button {
            onSelectStory(story)
        } label: {
            HStack(spacing: Spacing.medium) {
                IconTile(
                    symbolName: story.symbolName,
                    size: Size.rowIcon,
                    tint: Palette.brand,
                    fill: Palette.brandSubtle
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(story.code) \(story.title)")
                        .font(Typography.headline)
                    Text(story.summary)
                        .font(Typography.footnote)
                        .foregroundStyle(Palette.textTertiary.color)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .foregroundStyle(Palette.text.color)
        .accessibilityIdentifier(Identifiers.labStory(story))
        .exampleRow()
    }

    private func makeToolRow(for tool: LabTool) -> some View {
        Button {
            onSelectTool(tool)
        } label: {
            HStack(spacing: Spacing.medium) {
                IconTile(
                    symbolName: tool.symbolName,
                    size: Size.rowIcon,
                    tint: Palette.accent,
                    fill: Palette.accentSubtle
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(tool.title)
                        .font(Typography.headline)
                    Text(tool.summary)
                        .font(Typography.footnote)
                        .foregroundStyle(Palette.textTertiary.color)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                toolCount(for: tool)
            }
        }
        .foregroundStyle(Palette.text.color)
        .accessibilityIdentifier(Identifiers.labTool(tool))
        .exampleRow()
    }

    @ViewBuilder
    private func toolCount(for tool: LabTool) -> some View {
        if tool == .eventLog, eventCount > 0 {
            Text(eventCount, format: .number)
                .font(Typography.label)
                .foregroundStyle(Palette.textTertiary.color)
        }
    }
}
