//
//  LateResultView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// VM-02: open the demo product, tap Reviews, and close the product before they arrive. The model's
// navigator outlives the flow, so its late push returns `.ignored` and logs `staleNavigator`; the
// screen shows what it returned, read from the demo coordinator so it appears as soon as it
// arrives. The screen reports Open product.
struct LateResultView: View {
    private static let steps = "Reviews take a moment to load. Close the product first: the push that "
        + "follows finds no flow and does nothing."

    let demos: LabDemoCoordinator
    let onOpen: () -> Void

    var body: some View {
        List {
            Section {
                LabNote(
                    title: "Tap Reviews, then Close",
                    detail: Self.steps
                )
                .listRowInsets(EdgeInsets())
            }
            outcomeSection
            Section {
                openButton
            }
        }
        .exampleList()
    }

    @ViewBuilder
    private var outcomeSection: some View {
        if let lateOutcome = demos.lateOutcome {
            Section("Reviews arrived after you left") {
                Text(lateOutcome)
                    .font(Typography.code)
                    .foregroundStyle(Palette.text.color)
                    .accessibilityIdentifier(Identifiers.labLateOutcome)
            }
        }
    }

    private var openButton: some View {
        PrimaryActionButton(
            title: "Open the product",
            identifier: Identifiers.labOpenLateDemo,
            action: onOpen
        )
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }
}
