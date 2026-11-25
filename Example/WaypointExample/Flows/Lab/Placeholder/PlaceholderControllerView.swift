//
//  PlaceholderControllerView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCatalog
import SwiftUI

// Hosts the UIKit placeholder in the app's SwiftUI stack.
//
// Conformances:
// - `UIViewControllerRepresentable`, so SwiftUI can push a UIKit flow's placeholder like any other
//   screen.
package struct PlaceholderControllerView: UIViewControllerRepresentable {
    package let entry: FlowEntry

    package func makeUIViewController(context: Context) -> PlaceholderViewController {
        PlaceholderViewController(entry: entry)
    }

    package func updateUIViewController(
        _ controller: PlaceholderViewController,
        context: Context
    ) { }
}
