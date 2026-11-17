//
//  Branch.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// The two branches on Home. Each branch is hosted by one UI framework and can launch either kind of flow.
//
// Conformances:
// - `String` raw values, so a launch argument such as `-branch uikit` names a branch, and accessibility
//   identifiers use the same word.
// - `CaseIterable`, so Home and the UI tests list every branch from this one declaration.
enum Branch: String, CaseIterable {
    case swiftUI = "swiftui"
    case uiKit = "uikit"

    var title: String {
        switch self {
        case .swiftUI:
            return "SwiftUI branch"
        case .uiKit:
            return "UIKit branch"
        }
    }

    var summary: String {
        switch self {
        case .swiftUI:
            return "Hosted in SwiftUI, launches either kind of flow"
        case .uiKit:
            return "Hosted in a view controller, same five flows"
        }
    }

    var symbolName: String {
        switch self {
        case .swiftUI:
            return "chevron.left.forwardslash.chevron.right"
        case .uiKit:
            return "square.stack.3d.up"
        }
    }

    var hostKind: FlowKind {
        switch self {
        case .swiftUI:
            return .swiftUI
        case .uiKit:
            return .uiKit
        }
    }
}
