//
//  NavigationRouter.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
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
    var isAttached: Bool { get }

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

    /// The stack on screen in this flow: the stack itself, or a tab container's selected stack.
    var shownStack: any TreeNode { get }

    /// The routes on screen in this flow, root route first: a stack's routes, or a tab
    /// container's selected stack.
    var shownRoutes: [AnyRoute] { get }

    /// This router and the routers inside it, as the readable tree prints them.
    func readableTree(_ naming: RouteNaming) -> ReadableTree

    /// Marks this router as in the tree.
    func markAttached()

    /// Marks this router as gone from the tree.
    func markDetached()
}

extension TreeNode {
    /// The root of the tree.
    var rootNode: any TreeNode {
        parentNode?.rootNode ?? self
    }

    /// The fallback this router's policy, or the nearest parent's, sets for a kind.
    func policyFallback(for kind: NavigationIssue.Kind) -> NavigationFallback? {
        fallbackPolicy[kind] ?? parentNode?.policyFallback(for: kind)
    }

    /// This router, or the router inside it with this flow.
    func node(for flow: FlowID) -> (any TreeNode)? {
        guard flowID != flow else {
            return self
        }
        return childNodes.lazy.compactMap { $0.node(for: flow) }.first
    }

    /// Marks this router and everything inside it as gone from the tree.
    func detachSubtree() {
        markDetached()
        tree.releaseFlowName(flowID)
        for child in childNodes {
            child.detachSubtree()
        }
    }

    /// The router that presented this router's flow: the nearest ancestor whose presented flow
    /// is this router or contains it.
    func presenter() -> (any TreeNode)? {
        guard let parent = parentNode else {
            return nil
        }
        return parent.presentedNode === self ? parent : parent.presenter()
    }
}
