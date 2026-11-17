//
//  SheetOptions.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// Options for a sheet.
///
/// Every value has a default, and nothing is fixed: set defaults for a flow or the whole app with
/// ``PresentationDefaults``, and a single call can still choose its own options.
///
/// Conformances:
/// - `Hashable`, so presentations can be compared.
/// - `Codable`, so it can be saved, restored and logged.
/// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
public struct SheetOptions: Hashable, Codable, Sendable {
    /// The sizes the sheet can rest at. Default: `[.large]`.
    public var detents: [SheetDetent]

    /// The size the sheet opens at. `nil` means the first detent.
    public var selectedDetent: SheetDetent?

    /// The tallest a `.fitsContent` sheet can grow. Taller content scrolls. Default: `.large`.
    public var fitsContentLimit: SheetDetent

    /// Whether the drag indicator shows. `nil` lets the platform decide.
    public var showsDragIndicator: Bool?

    /// Whether the user can swipe the sheet away. Default: `true`.
    public var allowsInteractiveDismiss: Bool

    /// Creates sheet options. Every argument has a default.
    public init(
        detents: [SheetDetent] = [.large],
        selectedDetent: SheetDetent? = nil,
        fitsContentLimit: SheetDetent = .large,
        showsDragIndicator: Bool? = nil,
        allowsInteractiveDismiss: Bool = true
    ) {
        self.detents = detents
        self.selectedDetent = selectedDetent
        self.fitsContentLimit = fitsContentLimit
        self.showsDragIndicator = showsDragIndicator
        self.allowsInteractiveDismiss = allowsInteractiveDismiss
    }

    /// A large sheet that the user can swipe away.
    public static var `default`: SheetOptions {
        SheetOptions()
    }
}
