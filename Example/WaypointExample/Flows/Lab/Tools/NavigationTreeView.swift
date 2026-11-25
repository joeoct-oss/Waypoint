//
//  NavigationTreeView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCatalog
import ExampleDesignSystem
import SwiftUI
import UIKit

// The whole app's navigation tree as the routers print it with `debugTree()`: the tab router,
// each tab's stack with its routes, and any flow presented over them. Route values stay private.
// Copy puts the text on the pasteboard for a bug report.
struct NavigationTreeView: View {
    // A deep tree is wider than the screen, so the text scrolls both ways.
    private static let scrollAxes: Axis.Set = [
        .vertical,
        .horizontal,
    ]

    let tree: String

    var body: some View {
        ScrollView(Self.scrollAxes) {
            Text(tree)
                .font(Typography.code)
                .foregroundStyle(Palette.text.color)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.large)
                .accessibilityIdentifier(Identifiers.navigationTree)
        }
        .background(Palette.background.color)
        .toolbar { copyItem }
    }

    private var copyItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Copy as text", systemImage: "doc.on.doc", action: copyTree)
                .accessibilityIdentifier(Identifiers.copyTree)
        }
    }

    private func copyTree() {
        UIPasteboard.general.string = tree
    }
}
