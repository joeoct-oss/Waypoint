//
//  Typography.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import UIKit

// The type roles from the design system, mapped to Dynamic Type text styles so every screen scales with
// the reader's text size. The design's families (Inter for the app, Unbounded for brand moments,
// JetBrains Mono for what Waypoint prints) map to the system's default, rounded and monospaced designs.
enum Typography {
    static var largeTitle: Font {
        .largeTitle.weight(.bold)
    }

    static var display: Font {
        .system(.title2, design: .rounded).weight(.bold)
    }

    static var title: Font {
        .title3.weight(.bold)
    }

    static var headline: Font {
        .headline
    }

    static var body: Font {
        .body
    }

    static var callout: Font {
        .callout
    }

    static var footnote: Font {
        .footnote
    }

    static var label: Font {
        .caption.weight(.semibold)
    }

    static var code: Font {
        .system(.footnote, design: .monospaced)
    }

    static var uiHeadline: UIFont {
        .preferredFont(forTextStyle: .headline)
    }

    static var uiBody: UIFont {
        .preferredFont(forTextStyle: .body)
    }

    static var uiFootnote: UIFont {
        .preferredFont(forTextStyle: .footnote)
    }

    static var uiDisplay: UIFont {
        roundedFont(for: .title2, weight: .bold)
    }

    static var uiCode: UIFont {
        let size = UIFont.preferredFont(forTextStyle: .footnote).pointSize
        return .monospacedSystemFont(ofSize: size, weight: .regular)
    }

    private static func roundedFont(
        for style: UIFont.TextStyle,
        weight: UIFont.Weight
    ) -> UIFont {
        let base = UIFont.preferredFont(forTextStyle: style)
        let bold = UIFont.systemFont(ofSize: base.pointSize, weight: weight)
        let rounded = bold.fontDescriptor.withDesign(.rounded) ?? bold.fontDescriptor
        return UIFont(descriptor: rounded, size: base.pointSize)
    }
}
