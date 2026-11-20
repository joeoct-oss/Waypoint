//
//  FlowKind.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// The UI framework a flow is built with.
//
// Conformances:
// - `String` raw values, so a launch argument such as `-kind swiftui` names a kind, and
//   accessibility identifiers use the same word.
// - `Codable` (from the raw values), so a Lab entry can sit in an account route.
// - `CaseIterable`, so every flow row offers both kinds in one order.
enum FlowKind: String, CaseIterable, Codable {
    case swiftUI = "swiftui"
    case uiKit = "uikit"

    var title: String {
        switch self {
        case .swiftUI:
            return "SwiftUI"
        case .uiKit:
            return "UIKit"
        }
    }

    var buttonTitle: String {
        switch self {
        case .swiftUI:
            return "SwiftUI flow"
        case .uiKit:
            return "UIKit flow"
        }
    }
}
