//
//  SheetOptionsModifier.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import Waypoint

// Draws a sheet the way its Waypoint `SheetOptions` say: the sizes it rests at and opens at, the
// drag indicator, and whether a swipe can close it. The app's sheets are still SwiftUI's own, bound
// to the routers, so this is the one place that turns the router's options into SwiftUI modifiers;
// no screen sets a detent of its own. It goes away when Waypoint draws sheets (#12).
//
// `.fitsContent` and app-defined sizes need that renderer, so until then they show as large.
//
// Conformances:
// - `ViewModifier`, so a coordinator gives its sheet's content `.sheetOptions(_:)`.
struct SheetOptionsModifier: ViewModifier {
    let options: SheetOptions
    // `var` because the reader drags the sheet between its sizes.
    @State private var selection: PresentationDetent

    private var detents: Set<PresentationDetent> {
        Set(options.detents.map(Self.presentationDetent(for:)))
    }

    private var dragIndicator: Visibility {
        switch options.showsDragIndicator {
        case .some(true):
            return .visible
        case .some(false):
            return .hidden
        case .none:
            return .automatic
        }
    }

    init(options: SheetOptions) {
        self.options = options
        let opening = options.selectedDetent ?? options.detents.first ?? .large
        _selection = State(initialValue: Self.presentationDetent(for: opening))
    }

    private static func presentationDetent(for detent: SheetDetent) -> PresentationDetent {
        switch detent {
        case .medium:
            return .medium
        case .large, .fitsContent, .custom:
            return .large
        case .fraction(let fraction):
            return .fraction(fraction)
        case .height(let height):
            return .height(height)
        }
    }

    func body(content: Content) -> some View {
        content
            .presentationDetents(detents, selection: $selection)
            .presentationDragIndicator(dragIndicator)
            .interactiveDismissDisabled(!options.allowsInteractiveDismiss)
    }
}

extension View {
    // Sizes and locks the sheet this view is the content of. A new set of options, such as the
    // saved sheet swapping to the wish list, starts at its own opening size.
    func sheetOptions(_ options: SheetOptions?) -> some View {
        modifier(SheetOptionsModifier(options: options ?? .default))
            .id(options)
    }
}
