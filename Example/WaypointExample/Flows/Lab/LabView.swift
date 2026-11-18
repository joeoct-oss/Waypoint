//
//  LabView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// The Navigation Lab: one row per branch, each opening the five demo flows in both kinds. The screen
// reports the branch the reader picks, and the account coordinator opens it. The bar already shows the
// Lab's name, so the list's header shows only its slogan.
struct LabView: View {
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
}
