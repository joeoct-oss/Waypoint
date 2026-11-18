//
//  AppWindow.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Holds one window's app coordinator, made once, and draws its current root. Apps never write this
// view: they call `AppCoordinator.makeWindow(launch:)`. Once the SwiftUI renderer is built,
// `makeWindow` returns `WaypointRoot { AppCoordinator(...) }` instead and this file goes away, with
// the same shape: one coordinator per window.
struct AppWindow: View {
    @State private var app: AppCoordinator

    init(makeCoordinator: () -> AppCoordinator) {
        _app = State(initialValue: makeCoordinator())
    }

    var body: some View {
        app.makeFlow(for: app.root)
            .tint(Palette.brand.color)
    }
}
