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
    /// A large sheet that the user can swipe away.
    public static var `default`: SheetOptions {
        SheetOptions()
    }

    /// The sizes the sheet can rest at, never empty. Default: `[.large]`.
    public let detents: [SheetDetent]

    /// The size the sheet opens at, always one of ``detents``. `nil` means the first detent.
    public let selectedDetent: SheetDetent?

    /// The tallest a `.fitsContent` sheet can grow. Taller content scrolls. Default: `.large`.
    public let fitsContentLimit: SheetDetent

    /// Whether the drag indicator shows. `nil` lets the platform decide.
    public let showsDragIndicator: Bool?

    /// Whether the user can swipe the sheet away. Default: `true`.
    public let allowsInteractiveDismiss: Bool

    /// Creates sheet options. Every argument has a default.
    ///
    /// The options are always valid: an empty `detents` becomes `[.large]`, a `selectedDetent`
    /// that isn't one of `detents` becomes `nil`, and a `fitsContentLimit` of `.fitsContent`,
    /// which is not a limit, becomes `.large`.
    public init(
        detents: [SheetDetent] = [.large],
        selectedDetent: SheetDetent? = nil,
        fitsContentLimit: SheetDetent = .large,
        showsDragIndicator: Bool? = nil,
        allowsInteractiveDismiss: Bool = true
    ) {
        let detents = detents.isEmpty ? [.large] : detents
        self.detents = detents
        self.selectedDetent = selectedDetent.flatMap { detents.contains($0) ? $0 : nil }
        self.fitsContentLimit = fitsContentLimit == .fitsContent ? .large : fitsContentLimit
        self.showsDragIndicator = showsDragIndicator
        self.allowsInteractiveDismiss = allowsInteractiveDismiss
    }

    /// Decodes saved options through the initializer above, so saved options are checked like
    /// new ones.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            detents: try container.decode([SheetDetent].self, forKey: .detents),
            selectedDetent: try container.decodeIfPresent(SheetDetent.self, forKey: .selectedDetent),
            fitsContentLimit: try container.decode(SheetDetent.self, forKey: .fitsContentLimit),
            showsDragIndicator: try container.decodeIfPresent(Bool.self, forKey: .showsDragIndicator),
            allowsInteractiveDismiss: try container.decode(Bool.self, forKey: .allowsInteractiveDismiss)
        )
    }

    /// The same options with other sizes. The selected size is kept if it is one of them.
    public func withDetents(_ detents: [SheetDetent], selected: SheetDetent? = nil) -> SheetOptions {
        SheetOptions(
            detents: detents,
            selectedDetent: selected ?? selectedDetent,
            fitsContentLimit: fitsContentLimit,
            showsDragIndicator: showsDragIndicator,
            allowsInteractiveDismiss: allowsInteractiveDismiss
        )
    }

    /// The same options with another limit for `.fitsContent` sheets.
    public func withFitsContentLimit(_ limit: SheetDetent) -> SheetOptions {
        SheetOptions(
            detents: detents,
            selectedDetent: selectedDetent,
            fitsContentLimit: limit,
            showsDragIndicator: showsDragIndicator,
            allowsInteractiveDismiss: allowsInteractiveDismiss
        )
    }

    /// The same options with the drag indicator shown, hidden, or left to the platform.
    public func withDragIndicator(_ shows: Bool?) -> SheetOptions {
        SheetOptions(
            detents: detents,
            selectedDetent: selectedDetent,
            fitsContentLimit: fitsContentLimit,
            showsDragIndicator: shows,
            allowsInteractiveDismiss: allowsInteractiveDismiss
        )
    }

    /// The same options, with swiping the sheet away allowed or not.
    public func withInteractiveDismiss(_ allowed: Bool) -> SheetOptions {
        SheetOptions(
            detents: detents,
            selectedDetent: selectedDetent,
            fitsContentLimit: fitsContentLimit,
            showsDragIndicator: showsDragIndicator,
            allowsInteractiveDismiss: allowed
        )
    }
}
