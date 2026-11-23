//
//  ChildFlow.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// A child flow a parent started for a coordinator, kept on the child's router until it ends.
///
/// Conformances:
/// - `AnyObject`, because one record is kept by one router and ended once.
@MainActor
protocol ChildFlowRecord: AnyObject {
    /// Whether the start that made it was committed. A record whose start was rolled back never
    /// ends.
    var isStarted: Bool { get }

    /// Marks the start as committed.
    func start()

    /// Gives the parent the flow's result: the value it finished with, or `.cancelled`.
    func end()
}

/// A child flow whose coordinator finishes with `Output`: the coordinator, held while the flow
/// runs, and what the parent gets when it ends.
///
/// Conformances:
/// - `ChildFlowRecord`, so the child's router can end it without knowing `Output`.
@MainActor
final class ChildFlow<Output: Sendable>: ChildFlowRecord {
    /// The child coordinator, held strongly so the flow lives as long as its router is in the
    /// tree, even when the parent keeps no reference to it.
    private let coordinator: AnyObject

    /// The parent's `onFinish:`.
    private let onFinish: (FlowResult<Output>) -> Void

    /// The value the coordinator finished with, or `nil` while it hasn't.
    ///
    /// `var` because the coordinator finishes after the flow starts. Only `keep(_:)` changes it.
    private var output: Output?

    /// Whether the start that made it was committed.
    ///
    /// `var` because the start commits after the record is made. Only `start()` changes it.
    private(set) var isStarted = false

    /// A record for `coordinator`, whose parent gets the result in `onFinish`.
    init(coordinator: AnyObject, onFinish: @escaping (FlowResult<Output>) -> Void) {
        self.coordinator = coordinator
        self.onFinish = onFinish
    }

    /// Keeps the first value the coordinator finishes with. Later ones are dropped.
    func keep(_ output: Output) {
        guard self.output == nil else {
            return
        }
        self.output = output
    }

    /// Marks the start as committed.
    func start() {
        isStarted = true
    }

    /// Calls `onFinish` with the kept value, or `.cancelled`.
    func end() {
        let result = output.map(FlowResult.finished) ?? .cancelled
        onFinish(result)
    }
}
