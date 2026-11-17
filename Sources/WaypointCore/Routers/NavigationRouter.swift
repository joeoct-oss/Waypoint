//
//  NavigationRouter.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// What every router has in common.
///
/// Conformances:
/// - `AnyObject`, because every router is one shared object in the tree.
@MainActor
public protocol NavigationRouter: AnyObject {
    /// The flow this router drives.
    var flowID: FlowID { get }

    /// The router that presented or contains this one, or `nil` for the root.
    var parent: (any NavigationRouter)? { get }

    /// The routers inside this one: each tab's stack, then the presented flow.
    var children: [any NavigationRouter] { get }

    /// Whether this router is still in the tree. A router whose flow was dismissed, or whose tab
    /// was removed, ignores every call and returns `.ignored`.
    var isActive: Bool { get }
}

/// What the tree needs from each router. Internal, so the public protocol stays small.
///
/// Conformances:
/// - `NavigationRouter`, so every node is a public router.
/// - `TransactionParticipant`, so a transaction can change it and commit or roll back.
@MainActor
protocol TreeNode: NavigationRouter, TransactionParticipant {
    /// The tree this router belongs to.
    var tree: NavigationTreeContext { get }

    /// The parent as a tree node.
    var parentNode: (any TreeNode)? { get }

    /// Whether this router is in the tree.
    var isAttached: Bool { get set }

    /// The committed presented flow, if any.
    var presentedNode: (any TreeNode)? { get }

    /// The committed routers inside this one.
    var childNodes: [any TreeNode] { get }

    /// Presentation defaults, own or inherited.
    var presentationDefaults: PresentationDefaults { get }

    /// The committed path of this router's stack, or empty for a container.
    var currentPath: [AnyRoute] { get }

    /// This router's own fallback policy.
    var fallbackPolicy: FallbackPolicy { get }
}

extension TreeNode {
    /// The root of the tree.
    var rootNode: any TreeNode {
        var node: any TreeNode = self
        while let parent = node.parentNode {
            node = parent
        }
        return node
    }

    /// The fallback this router's policy, or the nearest parent's, sets for a kind.
    func policyFallback(for kind: NavigationIssue.Kind) -> NavigationFallback? {
        fallbackPolicy[kind] ?? parentNode?.policyFallback(for: kind)
    }

    /// Marks this router and everything inside it as gone from the tree.
    func detachSubtree() {
        isAttached = false
        tree.releaseFlowName(flowID)
        for child in childNodes {
            child.detachSubtree()
        }
    }

    /// The router that presented this router's flow: the nearest ancestor whose presented flow
    /// is this router or contains it.
    func presenter() -> (any TreeNode)? {
        var node: any TreeNode = self
        while let parent = node.parentNode {
            if parent.presentedNode === node {
                return parent
            }
            node = parent
        }
        return nil
    }
}
