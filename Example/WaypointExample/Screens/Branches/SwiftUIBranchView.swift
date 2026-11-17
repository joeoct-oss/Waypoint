//
//  SwiftUIBranchView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// The SwiftUI branch: the five flows, each launchable as a SwiftUI flow or a UIKit flow. The screen
// reports the entry the reader picks, and the app coordinator opens it.
struct SwiftUIBranchView: View {
    let onSelect: (FlowEntry) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(ExampleFlow.allCases, id: \.self) { flow in
                    row(for: flow)
                }
            }
            .card()
            .padding(.horizontal, Spacing.large)
            .padding(.bottom, Spacing.large)
        }
        .background(Palette.background.color)
    }

    @ViewBuilder
    private func row(for flow: ExampleFlow) -> some View {
        if flow != ExampleFlow.allCases.first {
            Divider()
                .overlay(Palette.line.color)
        }
        FlowRow(
            branch: .swiftUI,
            flow: flow,
            onSelect: onSelect
        )
    }
}
