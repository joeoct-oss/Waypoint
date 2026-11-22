//
//  Palette.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// The color tokens from the example app's design system, built on the Waypoint identity's
// Constellation palette. Text pairs pass 4.5:1 on their backgrounds in both appearances.
//
// Two roles carry meaning: `accent` (Nova) marks where you are, such as the current route and the
// SwiftUI kind, and `brand` (Star line) marks what you can do, such as actions, links and the UIKit
// kind. A call recovered by a fallback is `warning`, never `error`, because the call worked.
nonisolated enum Palette {
    static let background = ColorToken(light: 0xF7F8FF, dark: 0x0B0F2A)
    static let surface = ColorToken(light: 0xFFFFFF, dark: 0x151A3D)
    static let surfaceSecondary = ColorToken(light: 0xEEF0FB, dark: 0x1E2450)
    static let text = ColorToken(light: 0x0B0F2A, dark: 0xEEF0FF)
    static let textSecondary = ColorToken(light: 0x3E4566, dark: 0xC3C8E8)
    static let textTertiary = ColorToken(light: 0x5F6588, dark: 0x9BA2CC)
    static let line = ColorToken(light: 0xE1E4F5, dark: 0x2A3166)
    static let brand = ColorToken(light: 0x4F5FE0, dark: 0x8B98FF)
    static let brandSubtle = ColorToken(light: 0xECEEFF, dark: 0x232A5E)
    static let accent = ColorToken(light: 0xD62F86, dark: 0xFF5BAA)
    static let accentSubtle = ColorToken(light: 0xFDEAF3, dark: 0x3A1A3E)
    static let success = ColorToken(light: 0x0B7A55, dark: 0x4FD1A1)
    static let successSubtle = ColorToken(light: 0xE5F6EF, dark: 0x12332F)
    static let warning = ColorToken(light: 0x8F5200, dark: 0xF2B451)
    static let warningSubtle = ColorToken(light: 0xFFF3DF, dark: 0x3A2E14)
    static let error = ColorToken(light: 0xB8203A, dark: 0xFF7A8C)
    static let errorSubtle = ColorToken(light: 0xFDECEE, dark: 0x3E1A26)
    static let onBrand = ColorToken(light: 0xFFFFFF, dark: 0x0B0F2A)
    // The recovered toast is dark in both appearances, with amber for the outcome.
    static let toast = ColorToken(light: 0x151A3D, dark: 0x232A5E)
    static let onToast = ColorToken(light: 0xEEF0FF, dark: 0xEEF0FF)
    static let toastAmber = ColorToken(light: 0xF2B451, dark: 0xF2B451)
}
