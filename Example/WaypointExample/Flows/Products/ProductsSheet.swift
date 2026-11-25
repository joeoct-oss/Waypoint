//
//  ProductsSheet.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import Waypoint

// Shop's or Search's sheets. `MainTabView` gives it to the stack around the tabs, since a sheet on
// the tab's root doesn't show while a pushed screen covers the root.
//
// Conformances:
// - `ViewModifier`, so `MainTabView` gives it to the stack.
struct ProductsSheet: ViewModifier {
    let products: ProductsCoordinator

    func body(content: Content) -> some View {
        content.sheet(
            isPresented: Binding(reading: products.isShowingSheet, writing: products.syncSheet),
            onDismiss: products.releaseSheet
        ) {
            products.makeSheetFlow()
        }
    }
}
