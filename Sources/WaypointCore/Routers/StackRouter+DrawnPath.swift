//
//  StackRouter+DrawnPath.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// What one stack on screen shows when child flows are pushed on it. The parent's path ends with
// the marker of the child flow on top, the child's root screen, and the child's own path follows
// it on the same stack. A renderer draws this drawn path, and hands what the user does to it back
// to the router that owns each screen. `package`, so Waypoint's renderers call it and Linux tests
// cover it.

extension StackRouter {
    /// The routes one stack shows above its root screen: this router's path, then the drawn path
    /// of the child flow pushed on top, if any, whose root screen is this path's last route.
    package var drawnPath: [AnyRoute] {
        guard let child = pushedFlow else {
            return state.path
        }
        return state.path + child.drawnPath
    }

    /// The router that owns the screen at `index` of ``drawnPath``: this router for its own path,
    /// marker included, else the pushed child flow's router that owns it. An index past the end
    /// belongs to the router whose path ends the drawn path.
    package func drawnOwner(ofIndex index: Int) -> StackRouter {
        let own = state.path.count
        guard index >= own, let child = pushedFlow else {
            return self
        }
        return child.drawnOwner(ofIndex: index - own)
    }

    /// The router whose pushed child flow starts at `marker`, searched from this router up the
    /// pushed flows on its stack, or `nil` when none does.
    package func drawnParent(ofMarker marker: AnyRoute) -> StackRouter? {
        guard let child = pushedFlow else {
            return nil
        }
        guard child.marker == marker else {
            return child.drawnParent(ofMarker: marker)
        }
        return self
    }

    /// Reports that the stack now shows `count` routes of ``drawnPath`` above its root screen,
    /// after the user went back, to the router that owns the screen now on top.
    ///
    /// Going back into this router's own path pops it, which ends a pushed child flow with
    /// `.cancelled`. Going back to a pushed child's root screen, its marker, pops the child's own
    /// path. A count past the drawn path is reported as for ``rendererDidPop(toCount:file:line:)``.
    @discardableResult
    package func rendererDidPopDrawn(
        toCount count: Int,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> NavigationOutcome {
        let own = state.path.count
        guard count >= own, let child = pushedFlow else {
            return rendererDidPop(toCount: count, file: file, line: line)
        }
        return child.rendererDidPopDrawn(toCount: count - own, file: file, line: line)
    }
}
