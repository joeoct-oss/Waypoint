//
//  Screens.swift
//  RendererSpike (#250, throwaway)
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

/// Shows the environment values the E checks read.
struct EnvironmentProbe: View {
    @Environment(\.spikeValue) private var spikeValue
    @Environment(\.routerStandIn) private var router
    @Environment(Theme.self) private var theme: Theme?

    var body: some View {
        VStack(alignment: .leading) {
            Text("env-\(spikeValue)").accessibilityIdentifier("envValue")
            Text("obs-\(theme?.name ?? "missing")").accessibilityIdentifier("obsValue")
            Text(router).accessibilityIdentifier("routerValue")
        }
        .font(.caption)
    }
}

struct RootScreen: View {
    let tab: String

    var body: some View {
        List {
            Text("root-\(tab)").accessibilityIdentifier("root-\(tab)")
            EnvironmentProbe()
        }
        .navigationTitle(tab == "A" ? "Root" : "Second Root")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct PushedScreen: View {
    let route: Route
    let model: PathModel
    let hidesTabBar: Bool

    var body: some View {
        content
            .navigationTitle("Screen \(route.number)")
            .navigationBarTitleDisplayMode(.inline)
            .modifier(TabBarHider(hidden: hidesTabBar))
            .sheet(isPresented: sheetBinding(depth: 1)) {
                SheetScreen(model: model, depth: 1)
            }
    }

    @ViewBuilder private var content: some View {
        switch route.kind {
        case .plain: PlainContent(route: route)
        case .toolbar: ToolbarContent(route: route)
        case .search: SearchContent()
        }
    }

    private func sheetBinding(depth: Int) -> Binding<Bool> {
        Binding(
            get: { model.sheetDepth >= depth && model.path.last?.id == route.id },
            set: { if !$0, model.sheetDepth >= depth { model.sheetDepth = depth - 1 } }
        )
    }
}

private struct TabBarHider: ViewModifier {
    let hidden: Bool

    func body(content: Content) -> some View {
        if hidden {
            content.toolbar(.hidden, for: .tabBar)
        } else {
            content
        }
    }
}

private struct PlainContent: View {
    let route: Route

    var body: some View {
        List {
            Text("screen-\(route.number)").accessibilityIdentifier("screen-\(route.number)")
            EnvironmentProbe()
        }
    }
}

private struct ToolbarContent: View {
    let route: Route
    @State private var leading = 0
    @State private var trailing = 0

    var body: some View {
        List {
            Text("screen-\(route.number)").accessibilityIdentifier("screen-\(route.number)")
            Text("taps-\(leading)-\(trailing)").accessibilityIdentifier("toolbarTaps")
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Lead") { leading += 1 }.accessibilityIdentifier("leadItem")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Trail") { trailing += 1 }.accessibilityIdentifier("trailItem")
            }
        }
    }
}

private struct SearchContent: View {
    @State private var query = ""
    private let items = ["Apple", "Banana", "Cherry"]

    var body: some View {
        List(items.filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) }, id: \.self) {
            Text($0).accessibilityIdentifier("item-\($0)")
        }
        .searchable(text: $query)
    }
}

struct SheetScreen: View {
    let model: PathModel
    let depth: Int

    var body: some View {
        VStack(spacing: 24) {
            Text("sheet-\(depth)").accessibilityIdentifier("sheet-\(depth)")
            if depth == 1 {
                Button("Open sheet 2") { model.sheetDepth = 2 }.accessibilityIdentifier("openSheet2")
            }
            Button("Dismiss sheet \(depth)") { model.sheetDepth = depth - 1 }
                .accessibilityIdentifier("dismissSheet\(depth)")
        }
        .sheet(isPresented: Binding(
            get: { depth == 1 && model.sheetDepth >= 2 },
            set: { if !$0, model.sheetDepth >= 2 { model.sheetDepth = 1 } }
        )) {
            SheetScreen(model: model, depth: 2)
        }
    }
}
