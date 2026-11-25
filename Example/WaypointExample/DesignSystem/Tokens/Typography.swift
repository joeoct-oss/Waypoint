//
//  Typography.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import UIKit

// The type roles from the design system, mapped to Dynamic Type text styles so every screen scales
// with the reader's text size. The design's families (Inter for the app, Unbounded for brand
// moments, JetBrains Mono for what Waypoint prints) map to the system's default, rounded and
// monospaced designs.
package nonisolated enum Typography {
    package static var largeTitle: Font {
        .largeTitle.weight(.bold)
    }

    package static var display: Font {
        .system(.title2, design: .rounded).weight(.bold)
    }

    package static var title: Font {
        .title3.weight(.bold)
    }

    package static var headline: Font {
        .headline
    }

    package static var body: Font {
        .body
    }

    package static var callout: Font {
        .callout
    }

    package static var footnote: Font {
        .footnote
    }

    package static var label: Font {
        .caption.weight(.semibold)
    }

    package static var code: Font {
        .system(.footnote, design: .monospaced)
    }

    package static var uiHeadline: UIFont {
        .preferredFont(forTextStyle: .headline)
    }

    package static var uiBody: UIFont {
        .preferredFont(forTextStyle: .body)
    }

    package static var uiFootnote: UIFont {
        .preferredFont(forTextStyle: .footnote)
    }

    package static var uiButton: UIFont {
        let size = UIFont.preferredFont(forTextStyle: .callout).pointSize
        return .systemFont(ofSize: size, weight: .semibold)
    }

    package static var uiDisplay: UIFont {
        roundedFont(for: .title2, weight: .bold)
    }

    package static var uiCode: UIFont {
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
