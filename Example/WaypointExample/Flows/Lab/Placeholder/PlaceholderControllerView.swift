//
//  PlaceholderControllerView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Hosts the UIKit placeholder in the app's SwiftUI stack.
//
// Conformances:
// - `UIViewControllerRepresentable`, so SwiftUI can push a UIKit flow's placeholder like any other
//   screen.
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
