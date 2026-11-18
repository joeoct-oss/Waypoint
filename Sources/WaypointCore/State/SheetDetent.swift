//
//  SheetDetent.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// One size a sheet can rest at.
///
/// Sizes are plain values in the navigation state, so a restored or deep linked sheet comes back
/// at the same size, and tests can check it on Linux. The renderers turn them into the platform's
/// own sheet sizes.
///
/// Conformances:
/// - `NavigationValue`, so it can be compared and hashed, saved and restored, and sent off the main
///   actor.
/// - `CustomStringConvertible`, so presentation styles print their sizes as `[medium, large]`.
public enum SheetDetent: NavigationValue, CustomStringConvertible {
    /// About half the available height.
    case medium
    /// The full available height.
    case large
    /// A fraction of the available height, from 0 to 1.
    case fraction(Double)
    /// A fixed height in points.
    case height(Double)
    /// As tall as the sheet's content, up to ``SheetOptions/fitsContentLimit``.
    case fitsContent
    /// A size the app defines, resolved by a rule registered with the renderer.
    case custom(String)

    /// The case name, with its value: `medium`, `fraction(0.5)`, `custom(tall)`.
    public var description: String {
        switch self {
        case .medium:
            return "medium"
        case .large:
            return "large"
        case .fraction(let value):
            return "fraction(\(value))"
        case .height(let points):
            return "height(\(points))"
        case .fitsContent:
            return "fitsContent"
        case .custom(let name):
            return "custom(\(name))"
        }
    }
}
