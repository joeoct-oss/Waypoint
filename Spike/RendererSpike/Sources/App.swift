//
//  App.swift
//  RendererSpike (#250, throwaway)
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

@main
struct RendererSpikeApp: App {
    var body: some Scene {
        WindowGroup { SpikeRoot() }
    }
}

struct SpikeRoot: View {
    private let config = LaunchConfig.current
    @State private var modelA = PathModel()
    @State private var modelB = PathModel()
    @State private var theme = Theme()
    @State private var spikeValue = "outer"
    @State private var selection = "A"

    var body: some View {
        TabView(selection: $selection) {
            stack(modelA, tab: "A")
                .tabItem { Label("First", systemImage: "1.circle") }
                .tag("A")
            stack(modelB, tab: "B")
                .tabItem { Label("Second", systemImage: "2.circle") }
                .tag("B")
        }
        .environment(\.spikeValue, spikeValue)
        .environment(theme)
        .overlay(alignment: .trailing) { controls }
        .task {
            let count = UserDefaults.standard.integer(forKey: "autopush")
            guard count > 0 else { return }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            modelA.pushMany(count)
            if UserDefaults.standard.bool(forKey: "autoToolbar") { modelA.push(.toolbar) }
        }
    }

    @ViewBuilder
    private func stack(_ model: PathModel, tab: String) -> some View {
        switch config.renderer {
        case .swiftUI:
            SwiftUIStackRenderer(model: model, tab: tab, config: config)
        case .uiKit:
            UIKitStackRenderer(path: model.path, model: model, tab: tab, config: config, theme: theme)
                .ignoresSafeArea()
        }
    }

    private var controls: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(modelA.debugText).accessibilityIdentifier("modelPath")
            Text("\(config.renderer.rawValue) \(config.scenario)").accessibilityIdentifier("config")
            control("push1") { modelA.push() }
            control("push3") { modelA.pushMany(3) }
            control("pushMid") { modelA.pushThenPopMidTransition() }
            control("replace") { modelA.replace(with: 1) }
            control("popRoot") { modelA.popToRoot() }
            control("sheet") { modelA.sheetDepth = 1 }
            control("stress") { modelA.stress() }
            control("pushToolbar") { modelA.push(.toolbar) }
            control("pushSearch") { modelA.push(.search) }
            control("theme") { theme.name = theme.name == "red" ? "blue" : "red" }
            control("env") { spikeValue = spikeValue == "outer" ? "outer2" : "outer" }
        }
        .font(.system(size: 12))
        .padding(.trailing, 2)
        .offset(y: 40)
    }

    private func control(_ name: String, action: @escaping () -> Void) -> some View {
        Button(name, action: action)
            .accessibilityIdentifier(name)
            .padding(.horizontal, 4).padding(.vertical, 2)
            .background(.yellow.opacity(0.6))
    }
}
