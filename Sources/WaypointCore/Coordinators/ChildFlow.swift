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

    /// Marks the start as committed, and hands the coordinator to the router that presents the
    /// flow, which keeps it from now on.
    func start() -> AnyObject?

    /// Gives the parent the flow's result: the value it finished with, or `.cancelled`.
    func end()
}

/// A child flow whose coordinator finishes with `Output`: the coordinator, held until the flow
/// starts, and what the parent gets when it ends.
///
/// `Output` is `Sendable` because the parent gets it in a `FlowResult`, which is `Sendable`.
///
/// Conformances:
/// - `ChildFlowRecord`, so the child's router can end it without knowing `Output`.
@MainActor
final class ChildFlow<Output: Sendable>: ChildFlowRecord {
    /// The child coordinator, held strongly until the start commits, then handed to the router
    /// that presents the flow. The record never keeps it after that: the child's router keeps this
    /// record, and the router table keeps that router, so holding the coordinator here would keep
    /// all three alive after the presenting router is gone.
    ///
    /// `var` because the start hands it over. Only `start()` changes it.
    private var coordinator: AnyObject?

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

    /// Marks the start as committed, and hands over the coordinator.
    func start() -> AnyObject? {
        isStarted = true
        let started = coordinator
        coordinator = nil
        return started
    }

    /// Calls `onFinish` with the kept value, or `.cancelled`.
    func end() {
        let result = output.map(FlowResult.finished) ?? .cancelled
        onFinish(result)
    }
}
