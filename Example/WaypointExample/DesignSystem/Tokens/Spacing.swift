//
//  Spacing.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import CoreGraphics

// Spacing on a 4 pt grid, from the design system.
enum Spacing {
    static let extraSmall: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let extraLarge: CGFloat = 24
    static let huge: CGFloat = 32
}

// Corner radii from the design system.
enum Radius {
    static let field: CGFloat = 12
    static let card: CGFloat = 16
    static let sheet: CGFloat = 22
    static let banner: CGFloat = 20
}

// Sizes the design system fixes, such as the smallest touch target.
enum Size {
    static let minimumTouchTarget: CGFloat = 44
    static let rowIcon: CGFloat = 42
    static let cardIcon: CGFloat = 48
    static let trailHeight: CGFloat = 30
    static let placeholderIcon: CGFloat = 64
    static let productThumbnail: CGFloat = 64
    static let productHero: CGFloat = 220
    static let bannerArtWidth: CGFloat = 132
    static let bannerArtHeight: CGFloat = 80
    static let radio: CGFloat = 24
}
