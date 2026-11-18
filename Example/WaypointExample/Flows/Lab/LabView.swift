//
//  LabView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// The Navigation Lab: one row per branch, each opening the five demo flows in both kinds, then one
// row per story of the Views and view models epic. The screen reports the branch or story the
// reader picks, and the account coordinator opens it. The bar already shows the Lab's name, so the
// list's header shows only its slogan.
struct LabView: View {
    let onSelectBranch: (Branch) -> Void
    let onSelectStory: (ViewModelStory) -> Void

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
        HStack(spacing: Spacing.extraSmall) {
            Text("Try every flow")
                .foregroundStyle(Palette.textSecondary.color)
            Text("in SwiftUI and UIKit.")
                .fontWeight(.semibold)
                .foregroundStyle(Palette.accent.color)
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
}
