//
//  AppRootView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Makes this window's app coordinator once and draws its current root. `WaypointRoot {
// AppCoordinator(...) }` takes this view's place once the SwiftUI renderer is built, with the same
// shape: one coordinator per window.
struct AppRootView: View {
    @State private var app: AppCoordinator

    init(makeCoordinator: () -> AppCoordinator) {
        _app = State(initialValue: makeCoordinator())
    }

    var body: some View {
        app.makeFlow(for: app.root)
            .tint(Palette.brand.color)
    }
}
