//
//  NavigationTree.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// The erased navigation state of every flow, from the root down.
///
/// Snapshots, deep link plans and debug output use this form.
///
/// Conformances:
/// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
/// - `Equatable`, so tests and the router can compare values.
/// - `Codable`, so it can be saved, restored and logged.
/// - `NavigationDescribable`, for a short, stable, private-by-default description in logs, events and test failures.
public struct NavigationTree: Sendable, Equatable, Codable, NavigationDescribable {
    /// One flow in the tree.
    ///
    /// Conformances:
    /// - `Sendable`, so it can leave the main actor for logging, analytics and saving.
    /// - `Equatable`, so tests and the router can compare values.
    /// - `Codable`, so it can be saved, restored and logged.
    public indirect enum Node: Sendable, Equatable, Codable {
        /// A stack and its state.
        case stack(FlowID, StackState)
        /// A tab container: the selected tab's name and each tab's tree, by tab name.
        case tabs(FlowID, selection: String, tabs: [String: NavigationTree])
        /// A root container: the current root's name and its tree.
        case root(FlowID, current: String, child: NavigationTree?)
    }

    /// The root flow and everything shown inside it.
    public var root: Node

    /// The flows presented over this one, by the flow that presented them.
    public var presented: [FlowID: NavigationTree]

    /// Creates a tree.
    public init(root: Node, presented: [FlowID: NavigationTree] = [:]) {
        self.root = root
        self.presented = presented
    }

    /// The path from the root to what is on screen, such as
    /// `root(app) current=main > tabs(main) selection=shop > stack(shop)[ProductRoute(id: <private>)]`.
    public var description: String {
        debugDescription(revealingPrivateValues: false)
    }

    /// The same line, with route fields revealed when asked.
    public func debugDescription(revealingPrivateValues: Bool) -> String {
        let node = Self.describe(root, revealingPrivateValues)
        let presentedFlows = presented.keys.sorted { $0.name < $1.name }
        let presentedTrees = presentedFlows.compactMap { flow in
            presented[flow].map { "presented(\(flow)) \($0.debugDescription(revealingPrivateValues: revealingPrivateValues))" }
        }
        return ([node] + presentedTrees).joined(separator: " + ")
    }

    /// One node and the visible part of what it contains.
    private static func describe(_ node: Node, _ reveal: Bool) -> String {
        switch node {
        case .stack(let flow, let state):
            return describeStack(flow, state, reveal)
        case .tabs(let flow, let selection, let tabs):
            return describeTabs(flow, selection, tabs[selection], reveal)
        case .root(let flow, let current, let child):
            return describeRoot(flow, current, child, reveal)
        }
    }

    /// `stack(flow)[routes]`, with its presentation.
    private static func describeStack(_ flow: FlowID, _ state: StackState, _ reveal: Bool) -> String {
        "stack(\(flow))\(state.debugDescription(revealingPrivateValues: reveal))"
    }

    /// `tabs(flow) selection=name > selected tab`.
    private static func describeTabs(_ flow: FlowID, _ selection: String, _ selected: NavigationTree?, _ reveal: Bool) -> String {
        let head = "tabs(\(flow)) selection=\(selection)"
        guard let selected else {
            return head
        }
        return "\(head) > \(selected.debugDescription(revealingPrivateValues: reveal))"
    }

    /// `root(flow) current=name > child`.
    private static func describeRoot(_ flow: FlowID, _ current: String, _ child: NavigationTree?, _ reveal: Bool) -> String {
        let head = "root(\(flow)) current=\(current)"
        guard let child else {
            return head
        }
        return "\(head) > \(child.debugDescription(revealingPrivateValues: reveal))"
    }
}
