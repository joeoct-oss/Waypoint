//
//  PlaceholderControllerView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Hosts the UIKit placeholder in the app's SwiftUI stack.
//
// Conformances:
// - `UIViewControllerRepresentable`, so SwiftUI can push a UIKit flow's placeholder like any other screen.
struct PlaceholderControllerView: UIViewControllerRepresentable {
    let entry: FlowEntry

    func makeUIViewController(context: Context) -> PlaceholderViewController {
        PlaceholderViewController(entry: entry)
    }

    func updateUIViewController(
        _ controller: PlaceholderViewController,
        context: Context
    ) { }
}
