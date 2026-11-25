//
//  SheetDemoViews.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCatalog
import ExampleDesignSystem
import SwiftUI
import Waypoint

// Draws one stack of the Sheet story, the story's own or a presented level's, with the sheet or
// cover its router presents over it. A presented level draws the same way, so levels nest as deep
// as the reader presents them.
package struct SheetDemoStack: View {
    package let demo: SheetDemoCoordinator
    package let router: StackRouter
    // `nil` for the story's own stack.
    package let level: SheetDemoLevel?

    package var body: some View {
        WaypointStack(router) {
            screen
        }
        .sheet(
            isPresented: Binding(reading: demo.isShowing(over: router, cover: false), writing: sync),
            onDismiss: release
        ) {
            presented
        }
        .fullScreenCover(
            isPresented: Binding(reading: demo.isShowing(over: router, cover: true), writing: sync),
            onDismiss: release
        ) {
            presented
        }
    }

    @ViewBuilder
    private var screen: some View {
        if let level {
            SheetDemoLevelView(demo: demo, level: level)
        } else {
            SheetDemoRootView(demo: demo)
        }
    }

    // Erased, because a level draws another `SheetDemoStack` inside its own.
    private var presented: AnyView {
        guard let shown = demo.level(over: router) else {
            return AnyView(EmptyView())
        }
        let stack = SheetDemoStack(
            demo: demo,
            router: shown.router,
            level: shown
        )
        return AnyView(stack.sheetOptions(shown.options))
    }

    private func sync(_ isShowing: Bool) {
        demo.sync(isShowing, over: router)
    }

    private func release() {
        demo.release(over: router)
    }
}

// The Sheet story's own screen: the next sheet's size and swipe-to-close, Present sheet and
// Present cover, and the router's tree. The screen only reports the taps.
package struct SheetDemoRootView: View {
    private static let title = "Sheet"
    private static let sizeTitle = "Size"
    private static let swipeTitle = "Swipe down to close"
    private static let presentTitle = "Present sheet"
    private static let coverTitle = "Present cover"
    private static let treeTitle = "Navigation tree"

    package let demo: SheetDemoCoordinator

    private var closeItem: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Close", systemImage: "xmark") { demo.close() }
                .accessibilityIdentifier(Identifiers.labDemoClose)
        }
    }

    package var body: some View {
        List {
            Section {
                Picker(Self.sizeTitle, selection: Binding(reading: demo.size, writing: demo.setSize)) {
                    ForEach(SheetDemoSize.allCases, id: \.self) { size in
                        Text(size.title)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier(Identifiers.sheetDemoSize)
                Toggle(Self.swipeTitle, isOn: Binding(reading: demo.allowsSwipe, writing: demo.setAllowsSwipe))
                    .accessibilityIdentifier(Identifiers.sheetDemoSwipe)
            }
            Section {
                Button(Self.presentTitle) { demo.presentSheet(from: nil) }
                    .accessibilityIdentifier(Identifiers.sheetDemoPresent)
                Button(Self.coverTitle) { demo.presentCover(from: nil) }
                    .accessibilityIdentifier(Identifiers.sheetDemoCover)
            }
            Section(Self.treeTitle) {
                Text(demo.tree)
                    .font(Typography.code)
                    .accessibilityIdentifier(Identifiers.sheetDemoTree)
            }
        }
        .exampleList()
        .navigationTitle(Self.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { closeItem }
    }
}

// A level the Sheet story presented: Present on top, Dismiss through the router that presented it,
// Dismiss flow through its own router, and Dismiss all through the story's router. The screen
// only reports the taps.
package struct SheetDemoLevelView: View {
    private static let presentTitle = "Present on top"
    private static let dismissTitle = "Dismiss"
    private static let dismissFlowTitle = "Dismiss flow"
    private static let dismissAllTitle = "Dismiss all"

    package let demo: SheetDemoCoordinator
    package let level: SheetDemoLevel

    package var body: some View {
        List {
            Button(Self.presentTitle) { demo.presentSheet(from: level) }
                .accessibilityIdentifier(Identifiers.sheetDemoPresentOnTop)
            Button(Self.dismissTitle) { demo.dismiss(level) }
                .accessibilityIdentifier(Identifiers.sheetDemoDismiss)
            Button(Self.dismissFlowTitle) { demo.dismissFlow(level) }
                .accessibilityIdentifier(Identifiers.sheetDemoDismissFlow)
            Button(Self.dismissAllTitle) { demo.dismissAll() }
                .accessibilityIdentifier(Identifiers.sheetDemoDismissAll)
        }
        .exampleList()
        .navigationTitle("Level \(level.number)")
        .navigationBarTitleDisplayMode(.inline)
        // Contains its children, so each button keeps its own identifier.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(Identifiers.sheetDemoLevel(level.number))
    }
}
