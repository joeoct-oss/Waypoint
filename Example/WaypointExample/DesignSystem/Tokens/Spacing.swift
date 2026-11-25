//
//  Spacing.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import CoreGraphics

// Spacing on a 4 pt grid, from the design system.
package nonisolated enum Spacing {
    package static let extraSmall: CGFloat = 4
    package static let small: CGFloat = 8
    package static let medium: CGFloat = 12
    package static let large: CGFloat = 16
    package static let extraLarge: CGFloat = 24
    package static let huge: CGFloat = 32
}

// Corner radii from the design system.
package nonisolated enum Radius {
    package static let field: CGFloat = 12
    package static let card: CGFloat = 16
    package static let sheet: CGFloat = 22
    package static let banner: CGFloat = 20
}

// Sizes the design system fixes, such as the smallest touch target.
package nonisolated enum Size {
    package static let minimumTouchTarget: CGFloat = 44
    package static let rowIcon: CGFloat = 42
    package static let cardIcon: CGFloat = 48
    package static let trailHeight: CGFloat = 30
    package static let placeholderIcon: CGFloat = 64
    package static let productThumbnail: CGFloat = 64
    package static let productHero: CGFloat = 220
    package static let bannerArtWidth: CGFloat = 132
    package static let bannerArtHeight: CGFloat = 80
    package static let radio: CGFloat = 24
}
