//
//  ViewModelStory.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// The four stories of the design canvas's Views and view models epic, each one a screen in the
// Lab.
//
// Conformances:
// - `String` raw values, so each story has a stable name in accessibility identifiers.
// - `Codable` (from the raw values), so a story can sit in an account route.
// - `CaseIterable`, so the Lab lists every story from this one declaration.
// - `Hashable` (from the raw values), so the account stack can push a story's screen.
nonisolated enum ViewModelStory: String, CaseIterable, Codable {
    case style
    case lateResult
    case noRouter
    case preview

    var code: String {
        switch self {
        case .style:
            return "VM-01"
        case .lateResult:
            return "VM-02"
        case .noRouter:
            return "VM-03"
        case .preview:
            return "VM-04"
        }
    }

    var title: String {
        switch self {
        case .style:
            return "Navigation style"
        case .lateResult:
            return "Navigate after the flow is gone"
        case .noRouter:
            return "A wrapper with no router above it"
        case .preview:
            return "Preview a screen without the app"
        }
    }

    var summary: String {
        switch self {
        case .style:
            return "Outputs, an injected navigator or property wrappers"
        case .lateResult:
            return "A late push from a closed flow is ignored"
        case .noRouter:
            return "The call fails with noRouterInScope and names the fix"
        case .preview:
            return ".waypointPreview(flow:) gives a preview its stack"
        }
    }

    var symbolName: String {
        switch self {
        case .style:
            return "slider.horizontal.3"
        case .lateResult:
            return "clock.arrow.circlepath"
        case .noRouter:
            return "exclamationmark.triangle"
        case .preview:
            return "rectangle.on.rectangle"
        }
    }
}
