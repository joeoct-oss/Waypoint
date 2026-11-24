//
//  AppWindow.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import UIKit

// Holds one window's app coordinator, made once, and draws its current root. Apps never write this
// view: they call `AppCoordinator.makeWindow(services:launch:)`. Once the SwiftUI renderer is
// built, `makeWindow` returns `WaypointRoot { AppCoordinator(...) }` instead and this file goes
// away, with the same shape: one coordinator per window.
struct AppWindow: View {
    @State private var app: AppCoordinator

    init(makeCoordinator: () -> AppCoordinator) {
        _app = State(initialValue: makeCoordinator())
    }

    var body: some View {
        app.makeFlow(for: app.root)
            .tint(Palette.brand.color)
            .onAppear(perform: speedUpAnimationsIfAsked)
    }

    // Experiment: `-animationSpeed N` plays every animation in the app's windows N times faster,
    // to measure how much of a UI test run is spent waiting for animations.
    private func speedUpAnimationsIfAsked() {
        let speed = UserDefaults.standard.double(forKey: LaunchArgument.animationSpeed.rawValue)
        guard speed > 1 else {
            return
        }
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        for window in windows {
            window.layer.speed = Float(speed)
        }
    }
}
