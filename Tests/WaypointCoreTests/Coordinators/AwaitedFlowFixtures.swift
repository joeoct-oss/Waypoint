//
//  AwaitedFlowFixtures.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import WaypointCore
import WaypointTestSupport

/// How a test ends a child flow, so the `await` and `onFinish:` forms can be compared on each.
///
/// Conformances:
/// - `CaseIterable`, so a test runs once for each way.
enum FlowEnding: CaseIterable {
    /// The child calls `finish(with:)`.
    case finish
    /// The user swipes the sheet away.
    case userSwipe
    /// The child calls `dismissFlow()`.
    case dismissFlowFromChild
    /// Another presentation replaces the flow through the `.replacePresentation` fallback.
    case replacedByFallback
    /// The flow that presented the parent is dismissed.
    case grandparentDismiss
    /// The user dismisses the flow in the same change in which its code finishes it.
    case dismissWhileFinishing

    /// The order number a finishing flow ends with.
    static let order = "A-1"

    /// Ends `child`, presented by `parent`, which `grandparent` presented, this way.
    @MainActor
    func end(_ child: CheckoutFlowCoordinator, presentedBy parent: StackRouter, in grandparent: StackRouter) {
        switch self {
        case .finish:
            child.finish(with: Self.order)
        case .userSwipe:
            parent.rendererDidDismiss()
        case .dismissFlowFromChild:
            child.router.dismissFlow()
        case .replacedByFallback:
            parent.present(SettingsRoute(), else: .replacePresentation)
        case .grandparentDismiss:
            grandparent.dismiss()
        case .dismissWhileFinishing:
            dismissWhileFinishing(child, presentedBy: parent)
        }
    }

    /// Dismisses the flow and finishes it in one change, as when the user swipes the sheet away
    /// while the flow's code finishes it.
    @MainActor
    private func dismissWhileFinishing(_ child: CheckoutFlowCoordinator, presentedBy parent: StackRouter) {
        parent.transaction { transaction in
            transaction.dismiss()
            child.finish(with: Self.order)
        }
    }
}
