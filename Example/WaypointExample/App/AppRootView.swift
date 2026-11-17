//
//  AppRootView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Draws the app coordinator: Home at the root of one stack, and the coordinator's screens above it.
// `WaypointRoot(app)` takes this view's place once the SwiftUI renderer is built.
struct AppRootView: View {
    let app: AppCoordinator

    var body: some View {
        NavigationStack(path: makePathBinding(app.path)) {
            app.makeHomeFlow()
                .navigationDestination(for: AppScreen.self) { app.makeDestination(for: $0) }
        }
        .tint(Palette.brand.color)
    }

    // Reading `app.path` in `body` is what makes the view redraw when the coordinator pushes.
    private func makePathBinding(_ path: [AppScreen]) -> Binding<[AppScreen]> {
        Binding(
            get: { path },
            set: { app.syncPath($0) }
        )
    }
}
