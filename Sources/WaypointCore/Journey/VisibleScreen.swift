//
//  VisibleScreen.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// The screen on display in a whole tree, worked out from the committed routers: the topmost
/// presented flow, else the selected tab's stack, and the top of that stack.
@MainActor
struct VisibleScreen {
    /// What makes a screen on display the same one after a change: its flow, its place in the
    /// stack and its route. A push of an equal route on top of itself is another screen.
    ///
    /// Conformances:
    /// - `Hashable`, so the tracker can compare it with the last one.
    struct Key: Hashable {
        /// The screen's flow.
        let flow: FlowID

        /// The screen's place in its stack, 0 for the root screen.
        let index: Int

        /// The screen's route, or `nil` for a root screen with no route.
        let route: AnyRoute?
    }

    /// How a stack sits in the tree.
    enum Role {
        /// The tree's root stack.
        case root
        /// The stack of a tab, named like the tab.
        case tab(String)
        /// A presented flow's stack.
        case presented
    }

    /// One stack on the way from the tree's root to the screen on display.
    struct Level {
        /// The stack.
        let stack: StackRouter

        /// How it sits in the tree.
        let role: Role

        /// Its screens, root first.
        let screens: [ScreenReference]
    }

    /// The stacks from the tree's root to the screen on display, never empty.
    let levels: [Level]

    /// The screen on display.
    let screen: ScreenReference

    /// What makes the screen on display the same one after a change.
    let key: Key

    /// Whether the journey counts the screen on display.
    let isTracked: Bool

    /// Where this part of the journey started.
    let source: ScreenReference

    /// The screens from the tree's root to the one on display.
    let journey: [ScreenReference]

    /// The screen's step in its flow, if its flow has a fixed number of steps.
    let step: ScreenVisit.Step?

    /// Whether the screen is the root of a tab's stack.
    var isTabRoot: Bool {
        guard case .tab = levels.last?.role, key.index == 0 else {
            return false
        }
        return true
    }

    /// The screen on display in the tree that `root` starts, or `nil` when no stack is in it,
    /// such as a tab container with no tabs.
    init?(in root: any TreeNode) {
        let levels = Self.levels(from: root)
        guard let last = levels.last, let screen = last.screens.last else {
            return nil
        }
        let top = last.stack.shownRoutes.last
        self.levels = levels
        self.screen = screen
        self.key = Key(flow: last.stack.flowID, index: last.screens.count - 1, route: top)
        self.isTracked = top?.screenTraits.isTracked ?? true
        self.source = Self.source(of: last)
        self.journey = Self.journey(through: levels)
        self.step = Self.step(in: last)
    }

    /// The name of a tab, a flow or a root screen in words, starting with a capital: `Cart` for
    /// `cart`.
    static func words(_ name: String) -> String {
        let words = RouteDescriber.readableTypeName(name)
        return words.prefix(1).uppercased() + words.dropFirst()
    }

    /// The name of a stack's root screen when it has no root route: the name given to the
    /// stack, else its tab's or its flow's, in words.
    static func rootName(of stack: StackRouter) -> String {
        rootName(of: stack, role: role(of: stack))
    }

    /// The stacks on the way down from `node`: a stack, then what it presents; a container's
    /// selected tab, and what the container or the tab presents.
    private static func levels(from node: any TreeNode) -> [Level] {
        guard let stack = node as? StackRouter else {
            return containerLevels(node)
        }
        let own = level(of: stack)
        let above = stack.presentedNode.map(levels) ?? []
        return [own] + above
    }

    /// A container's selected stack and what is above it. What the container presents covers
    /// the whole container, so it wins over what the selected tab presents.
    private static func containerLevels(_ container: any TreeNode) -> [Level] {
        let shown = container.shownStack
        guard let presented = container.presentedNode else {
            return shown === container ? [] : levels(from: shown)
        }
        guard let stack = shown as? StackRouter else {
            return levels(from: presented)
        }
        return [level(of: stack)] + levels(from: presented)
    }

    /// One stack, with its role and its screens.
    static func level(of stack: StackRouter) -> Level {
        let role = role(of: stack)
        let rootRoute = stack.showsRootRoute ? stack.shownRoutes.first : nil
        let pushed = stack.showsRootRoute ? Array(stack.shownRoutes.dropFirst()) : stack.shownRoutes
        let owner = stack.coordinatorName
        let views = stack.tree.viewNames
        let rootView = stack.rootViewName ?? rootRoute.flatMap { views[$0.routeKey] }
        let root = rootRoute.map { route in
            ScreenReference(route: route, flow: stack.flowID, viewName: rootView, coordinator: owner)
        } ?? ScreenReference(
            rootNamed: rootName(of: stack, role: role),
            flow: stack.flowID,
            viewName: rootView,
            coordinator: owner
        )
        let pushedScreens = pushed.map { route in
            ScreenReference(route: route, flow: stack.flowID, viewName: views[route.routeKey], coordinator: owner)
        }
        let screens = [root] + pushedScreens
        return Level(stack: stack, role: role, screens: screens)
    }

    /// Whether a stack is the tree's root, a tab's stack or a presented flow.
    private static func role(of stack: StackRouter) -> Role {
        guard let parent = stack.parentNode else {
            return .root
        }
        guard parent.presentedNode === stack else {
            return .tab(words(stack.tabStackName))
        }
        return .presented
    }

    /// The name given to the stack, else its tab's or its flow's, in words.
    private static func rootName(of stack: StackRouter, role: Role) -> String {
        if let name = stack.rootName {
            return name
        }
        guard case .tab(let tab) = role else {
            return words(stack.flowID.name)
        }
        return tab
    }

    /// The nearest screen below the top that starts a journey, else the tab, else the stack's
    /// root screen.
    private static func source(of level: Level) -> ScreenReference {
        let below = level.screens.dropLast().reversed()
        if let starter = below.first(where: { $0.route?.screenTraits.startsJourney ?? false }) {
            return starter
        }
        guard case .tab(let tab) = level.role else {
            return level.screens[0]
        }
        return ScreenReference(rootNamed: tab, flow: level.stack.flowID)
    }

    /// Every level's tab and screens, without a name written twice in a row, such as a tab
    /// `Cart` whose root screen is also `Cart`.
    private static func journey(through levels: [Level]) -> [ScreenReference] {
        let all = levels.flatMap { level in
            tabScreen(of: level) + level.screens
        }
        return all.reduce(into: [ScreenReference]()) { journey, screen in
            guard journey.last?.title != screen.title else {
                return
            }
            journey.append(screen)
        }
    }

    /// The tab a level's stack belongs to, as a screen, or nothing.
    private static func tabScreen(of level: Level) -> [ScreenReference] {
        guard case .tab(let tab) = level.role else {
            return []
        }
        return [ScreenReference(rootNamed: tab, flow: level.stack.flowID)]
    }

    /// The top screen's step, when the stack's root route gives a number of steps and the top
    /// screen is a step: its root counts as step 1, then each pushed step.
    private static func step(in level: Level) -> ScreenVisit.Step? {
        let routes = level.stack.shownRoutes
        guard level.stack.showsRootRoute, let count = routes.first?.screenTraits.stepsInFlow else {
            return nil
        }
        let pushed = routes.dropFirst()
        guard pushed.last?.screenTraits.isFlowStep ?? true else {
            return nil
        }
        let number = 1 + pushed.filter(\.screenTraits.isFlowStep).count
        return number <= count ? ScreenVisit.Step(number: number, count: count) : nil
    }
}
