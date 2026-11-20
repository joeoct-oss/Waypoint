//
//  ScreenBinding.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// The screen of a stack a navigator was made for: its depth and the id it got when pushed.
///
/// A navigator does nothing once its screen is popped, even when another screen with the same
/// route is pushed in its place later, because that screen gets a new id. A screen still on the
/// stack keeps a live navigator, however many screens are pushed above it.
struct ScreenBinding: Equatable {
    /// The stack's root screen, which lives as long as its flow.
    static let root = ScreenBinding(depth: 0, id: 0)

    /// How many routes the path held with this screen on top. 0 is the root screen.
    let depth: Int

    /// The id the screen got when it was pushed. 0 for the root screen.
    let id: UInt64

    /// The ids of a path after it changed from `old` to `new`: the screens both paths share from
    /// the bottom keep their ids, and every other screen of `new` takes a new one from `claim`.
    static func ids(
        _ ids: [UInt64],
        from old: [AnyRoute],
        to new: [AnyRoute],
        claim: () -> UInt64
    ) -> [UInt64] {
        let kept = zip(old, new).prefix { pair in
            pair.0 == pair.1
        }
        let keptIDs = Array(ids.prefix(kept.count))
        let newIDs = (kept.count..<new.count).map { _ in
            claim()
        }
        return keptIDs + newIDs
    }
}

extension StackRouter {
    /// The screen on top of the committed path.
    var topScreen: ScreenBinding {
        guard let id = screenIDs.last else {
            return .root
        }
        return ScreenBinding(depth: screenIDs.count, id: id)
    }

    /// The top-most screen on the committed path that shows `route`, or the root screen when
    /// none does.
    func screen(showing route: AnyRoute) -> ScreenBinding {
        guard let index = state.path.lastIndex(of: route), index < screenIDs.count else {
            return .root
        }
        return ScreenBinding(depth: index + 1, id: screenIDs[index])
    }

    /// Whether `screen` is still on this stack. The root screen always is.
    func isOnStack(_ screen: ScreenBinding) -> Bool {
        guard screen.depth > 0 else {
            return true
        }
        return screen.depth <= screenIDs.count && screenIDs[screen.depth - 1] == screen.id
    }
}
