//
//  NavigationStyleView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// VM-01: pick how the demo product navigates, read the code that style needs, and try it. All three
// styles push the same cart through the same router, so guards, events and outcomes don't change.
// The screen reports Try it with the chosen style.
struct NavigationStyleView: View {
    let onTry: (NavigationStyle) -> Void

    @State private var style = NavigationStyle.navigator

    var body: some View {
        List {
            Section("How screens navigate") {
                picker
                Text(style.sample)
                    .font(Typography.code)
                    .foregroundStyle(Palette.text.color)
                    .accessibilityIdentifier(Identifiers.labStyleSample)
            }
            Section {
                LabNote(
                    title: "Same router underneath",
                    detail: "All three styles call the same router, so guards, events and outcomes do not change."
                )
                .listRowInsets(EdgeInsets())
            }
            Section {
                tryButton
            }
        }
        .exampleList()
    }

    private var picker: some View {
        Picker("Style", selection: $style) {
            ForEach(NavigationStyle.allCases) { style in
                Text(style.title)
                    .tag(style)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier(Identifiers.labStylePicker)
    }

    private var tryButton: some View {
        PrimaryActionButton(
            title: "Try \(style.title)",
            identifier: Identifiers.labTryStyle,
            action: { onTry(style) }
        )
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }
}
