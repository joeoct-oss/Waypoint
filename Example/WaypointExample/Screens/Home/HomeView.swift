//
//  HomeView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Home: the Waypoint header and one row per branch. The screen reports the branch the reader picks, and
// the app coordinator decides where that goes.
struct HomeView: View {
    let onSelectBranch: (Branch) -> Void

    var body: some View {
        List {
            Section {
                ForEach(Branch.allCases, id: \.self) { branch in
                    BranchRow(branch: branch) { onSelectBranch(branch) }
                }
            } header: {
                header
            }
        }
        .exampleList()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.extraSmall) {
            Text("Waypoint")
                .font(Typography.display)
                .foregroundStyle(Palette.text.color)
            slogan
        }
        .textCase(nil)
        .padding(.bottom, Spacing.small)
        .accessibilityElement(children: .combine)
    }

    private var slogan: some View {
        HStack(spacing: Spacing.extraSmall) {
            Text("Connect every screen.")
                .foregroundStyle(Palette.textSecondary.color)
            Text("Know every route.")
                .fontWeight(.semibold)
                .foregroundStyle(Palette.accent.color)
        }
        .font(Typography.callout)
    }
}
