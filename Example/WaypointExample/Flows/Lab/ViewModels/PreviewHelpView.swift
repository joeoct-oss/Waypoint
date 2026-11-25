//
//  PreviewHelpView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCatalog
import ExampleDesignSystem
import SwiftUI

// VM-04: how a screen that navigates draws in an Xcode preview. `.waypointPreview(flow:)` puts the
// view in a stack of its flow with a fresh, permissive router, so wrappers and navigators work and
// pushes need no destination. The demo product's own file has the previews.
struct PreviewHelpView: View {
    private static let sample = """
        #Preview("Wrappers") {
            WrapperProductView()
                .waypointPreview(flow: LabShopFlow.self)
        }
        """
    private static let explanation = "Without it, the wrapper finds no stack, so a tap fails with "
        + "noRouterInScope. With it, the preview needs no app coordinator and never crashes."

    var body: some View {
        List {
            Section("LabProductViews.swift") {
                Text(Self.sample)
                    .font(Typography.code)
                    .foregroundStyle(Palette.text.color)
                    .accessibilityIdentifier(Identifiers.labPreviewSample)
            }
            Section {
                LabNote(
                    title: "A router for the preview",
                    detail: Self.explanation
                )
                .listRowInsets(EdgeInsets())
            }
        }
        .exampleList()
    }
}
