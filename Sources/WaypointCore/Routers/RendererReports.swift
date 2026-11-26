//
//  RendererReports.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// Renderers call these when the user changes the screen directly: a swipe back, the back
// button or its long-press menu, a sheet dragged down, or a tab tap. Each report runs through
// the same reducers as an app call, as one transaction whose changes carry the `user` origin.
//
// Reports are idempotent: one that matches the current state changes nothing, so a change the
// app made that echoes back from the screen is ignored. They are `package`, so only Waypoint's
// own renderers and testing library can call them.

extension StackRouter {
    /// Reports that the stack now shows `count` routes above its root screen, after the user
    /// went back.
    ///
    /// A count equal to the path's is ignored. A count above it can't be matched, so the path
    /// is kept and `rendererMismatch` is reported. A count below zero is read as zero.
    @discardableResult
    package func rendererDidPop(
        toCount count: Int,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> NavigationOutcome {
        tree.perform(on: self, file: file, line: line) { [unowned self] store in
            store.asUser {
                let step = self.reportedPopStep(toCount: count, in: store, file: file, line: line)
                return store.resolveReport(step, file: file, line: line)
            }
        }
    }

    /// Reports that the flow this router presents is gone, after the user dragged its sheet
    /// down or the system closed it.
    ///
    /// Ignored when nothing is presented.
    @discardableResult
    package func rendererDidDismiss(file: StaticString = #fileID, line: UInt = #line) -> NavigationOutcome {
        tree.perform(on: self, file: file, line: line) { [unowned self] store in
            store.asUser {
                store.resolveReport(self.dismissStep(in: store), file: file, line: line)
            }
        }
    }

    /// Reports that the stack appeared on screen, so the journey writes the screen on display
    /// when no change has written it yet, such as the first screen at launch. Changes no state,
    /// and writes nothing when the screen on display is the latest visit's.
    package func rendererDidAppear(file: StaticString = #fileID, line: UInt = #line) {
        guard isAttached else {
            return
        }
        let noChanges: [AppliedChange] = []
        tree.trackJourney(noChanges, in: self, trigger: nil, file: file, line: line)
    }

    /// Reports that a renderer started drawing `coordinator`, whose router this is. Changes no
    /// state. Call ``rendererCheckDrawing(_:file:line:)`` once the drawing settles.
    package func rendererDidStartDrawing(_ coordinator: AnyObject) {
        coordinatorDrawings[ObjectIdentifier(coordinator), default: 0] += 1
    }

    /// Reports that a renderer stopped drawing `coordinator`.
    package func rendererDidStopDrawing(_ coordinator: AnyObject) {
        let key = ObjectIdentifier(coordinator)
        let count = (coordinatorDrawings[key] ?? 0) - 1
        coordinatorDrawings[key] = count > 0 ? count : nil
    }

    /// Reports `coordinatorDrawnTwice` when more than one renderer still draws `coordinator`: both
    /// drive this one router, so each shows the other's pushes. A renderer checks once the screen
    /// settled, after the call that started drawing, so a view that replaces another in one
    /// update, whose old copy stops after the new one starts, isn't reported.
    package func rendererCheckDrawing(_ coordinator: AnyObject, file: StaticString = #fileID, line: UInt = #line) {
        guard let count = coordinatorDrawings[ObjectIdentifier(coordinator)], count > 1 else {
            return
        }
        let name = ViewTypeName.of(type(of: coordinator))
        let message =
            "\(name).view is drawn in two places at once. Both drive \(flowID)'s one router, so "
            + "each place shows the other's pushes. Draw a coordinator's view in one place, and make "
            + "another \(name) for the second place."
        report(.coordinatorDrawnTwice, message, file: file, line: line)
    }

    /// Reports that the screen started animating the push of `route`.
    ///
    /// Until ``rendererDidEndPush(of:)``, a push of an equal route is skipped under
    /// ``DuplicatePushRule/skipWhileInFlight``. Changes no state. The push is measured as a
    /// `push` interval in `renderer`, a signpost in Instruments.
    package func rendererDidStartPush(of route: AnyRoute) {
        pushInFlight = route
        beginPushInterval()
    }

    /// Reports that the push of `route` finished animating. A report for another route, from a
    /// push that a newer one replaced, is ignored.
    package func rendererDidEndPush(of route: AnyRoute) {
        guard pushInFlight == route else {
            return
        }
        pushInFlight = nil
        endPushInterval()
    }

    /// Reports that the stack shows `route`, but no screen inside the stack registered a
    /// destination for its type, so the screen can't be drawn.
    ///
    /// The tree knows the type, because another stack registered it or the configuration's
    /// registry lists it, so the push itself went ahead. Keeps the path and reports
    /// `missingDestination` at `.fault`, with the fix. Returns the issue, so the renderer can show
    /// it.
    @discardableResult
    package func rendererFoundNoDestination(
        for route: AnyRoute,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> NavigationIssue {
        let issue = missingDestinationDraft(route).issue(file: file, line: line)
        _ = tree.perform(on: self, file: file, line: line) { store in
            store.keep(issue, level: .fault)
            return .unchanged
        }
        return issue
    }

    /// The issue for a route this stack has no destination for.
    private func missingDestinationDraft(_ route: AnyRoute) -> IssueDraft {
        let key = route.routeKey
        return IssueDraft(kind: .missingDestination, flow: flowID) { naming in
            "No destination for \(naming.typeName(key)) in this stack. The tree knows the type, but no "
                + "screen inside this stack registered it. Add .destination(\(key.typeName).self) { … } "
                + "to the stack's first screen or to a screen pushed before it."
        }
    }

    /// Pops to `count` routes, or reports a count the path can't match.
    private func reportedPopStep(
        toCount count: Int,
        in store: TransactionStore,
        file: StaticString,
        line: UInt
    ) -> StepResult {
        let shown = current.state.path.count
        let target = max(count, 0)
        guard target <= shown else {
            store.keep(mismatchIssue(reported: target, shown: shown, file: file, line: line), level: .error)
            return .unchanged
        }
        guard target < shown else {
            return .unchanged
        }
        return stackStep(.pop(count: shown - target), in: store)
    }

    /// The issue for a screen that shows more routes than the path holds.
    private func mismatchIssue(reported: Int, shown: Int, file: StaticString, line: UInt) -> NavigationIssue {
        let message =
            "The screen shows \(reported) routes but the path holds \(shown), so the path was kept. "
            + "A NavigationLink(value:) inside a Waypoint stack does this: use WaypointLink or router.push instead."
        return NavigationIssue(kind: .rendererMismatch, flow: flowID, message: message, file: file, line: line)
    }
}

extension TabRouter {
    /// Reports that the user selected `tab`.
    ///
    /// Ignored when `tab` is already selected: popping to the root on a second tap is the
    /// renderer's to report as a pop. A tab that isn't in the container reports `unknownTab`. With
    /// ``TabStacks/shared``, the shared stack pops in the same change.
    @discardableResult
    package func rendererDidSelect(
        _ tab: Tab,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> NavigationOutcome {
        tree.perform(on: self, file: file, line: line) { [unowned self] store in
            store.asUser {
                store.resolveReport(self.selectOtherStep(tab, in: store), file: file, line: line)
            }
        }
    }

    /// Reports that the flow this container presents is gone, after the user dragged its sheet
    /// down or the system closed it.
    ///
    /// Ignored when nothing is presented.
    @discardableResult
    package func rendererDidDismiss(file: StaticString = #fileID, line: UInt = #line) -> NavigationOutcome {
        tree.perform(on: self, file: file, line: line) { [unowned self] store in
            store.asUser {
                store.resolveReport(self.dismissStep(in: store), file: file, line: line)
            }
        }
    }
}

extension TransactionStore {
    /// Turns a report's step result into its call result. Reports run no fallback: the screen
    /// already shows the change, so a refused report fails and changes nothing.
    func resolveReport(_ result: StepResult, file: StaticString, line: UInt) -> CallResult {
        switch result {
        case .changed:
            return .changed
        case .unchanged:
            return .unchanged
        case .failed(let draft):
            return failedReport(draft.issue(file: file, line: line))
        }
    }

    /// Keeps a refused report's issue, and fails the report.
    private func failedReport(_ issue: NavigationIssue) -> CallResult {
        keep(issue, level: .fault)
        return .failed(NavigationFailure(issue: issue))
    }
}
