//
//  JourneyTree.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// The whole app as a tree, for the `app` part of the journey box: each coordinator, tab and
/// screen, with the screen on display marked.
///
/// ```text
/// MainCoordinator · tabs
/// ├─▶ Shop · ProductsCoordinator
/// │     ├ ProductListView
/// │     └ ProductDetailView (id: 4)   ◀ NEW
/// ├── Search · SearchCoordinator   └ SearchView
/// └── Account · AccountCoordinator └ AccountView
/// ```
@MainActor
struct JourneyTree {
    /// One line of the tree.
    struct Row {
        /// The line, without the marker.
        let text: String

        /// Whether the line is the screen on display.
        let isCurrent: Bool
    }

    /// How lines are drawn: with symbols or plain characters.
    private let symbols: Bool

    /// How route fields are written.
    private let naming: RouteNaming

    /// What makes the screen on display, to mark its line.
    private let current: VisibleScreen.Key?

    /// A tree that marks the screen that `current` names.
    init(current: VisibleScreen.Key?, naming: RouteNaming) {
        self.symbols = naming.usesSymbols
        self.naming = naming
        self.current = current
    }

    /// The lines of the tree that `root` starts: the root's header, then everything inside it.
    func rows(from root: any TreeNode) -> [Row] {
        guard let stack = root as? StackRouter else {
            let header = Row(text: "\(Self.owner(of: root)) \(dot) tabs", isCurrent: false)
            return [header] + containerRows(root)
        }
        let header = Row(text: "\(Self.owner(of: stack)) \(dot) stack", isCurrent: false)
        return [header] + stackRows(stack, prefix: "")
    }

    /// What the box calls a screen: its view, then its fields, such as
    /// `ProductDetailView (id: 4)`. Without a view name, its title, such as `Product 4`.
    static func label(of screen: ScreenReference, naming: RouteNaming) -> String {
        guard screen.viewName != nil else {
            return screen.title
        }
        return screen.screenLabel + fields(of: screen, naming: naming)
    }

    /// ` (id: 4)` for a route with fields shown, ` (payment)` for an enum case, else nothing.
    private static func fields(of screen: ScreenReference, naming: RouteNaming) -> String {
        guard let route = screen.route else {
            return ""
        }
        let name = naming.name(route)
        if let open = name.range(of: " (") {
            return String(name[open.lowerBound...])
        }
        return screen.detail.map { " (\($0))" } ?? ""
    }

    /// The name of a router's owner: its coordinator, else its flow in words.
    static func owner(of node: any TreeNode) -> String {
        node.coordinatorName ?? VisibleScreen.words(node.flowID.name)
    }

    /// A tab container's tabs, then what it presents.
    private func containerRows(_ container: any TreeNode) -> [Row] {
        let presented = container.presentedNode
        let tabs = container.childNodes.compactMap { node in
            node === presented ? nil : node as? StackRouter
        }
        let inlineWidth = tabs.map { tabLabel($0).count }.max() ?? 0
        let tabRows = tabs.enumerated().flatMap { index, tab in
            let isLast = index == tabs.count - 1 && presented == nil
            let isSelected = tab === container.shownStack
            return self.tabRows(tab, isLast: isLast, isSelected: isSelected, width: inlineWidth)
        }
        guard let presented = presented as? StackRouter else {
            return tabRows
        }
        return tabRows + presentedRows(presented, by: container, prefix: "", branch: corner(isLast: true))
    }

    /// One tab: expanded when it is selected or presents something, else on one line.
    private func tabRows(_ tab: StackRouter, isLast: Bool, isSelected: Bool, width: Int) -> [Row] {
        let rule = symbols ? "─" : "-"
        let arrow = isSelected ? (symbols ? "▶" : ">") : rule
        let branch = (isLast ? corner(isLast: true) : corner(isLast: false)) + rule + arrow + " "
        let label = tabLabel(tab)
        let below = isLast ? "      " : (symbols ? "│     " : "|     ")
        guard isSelected || tab.presentedNode != nil else {
            let screens = shortened(screenLabels(of: tab))
            let padded = label.padding(toLength: width, withPad: " ", startingAt: 0)
            return [Row(text: "\(branch)\(padded)  \(corner(isLast: true)) \(screens)", isCurrent: false)]
        }
        return [Row(text: branch + label, isCurrent: false)] + stackRows(tab, prefix: below)
    }

    /// `Shop · ProductsCoordinator`, or `Shop` when the tab's stack has no coordinator.
    private func tabLabel(_ tab: StackRouter) -> String {
        let name = VisibleScreen.words(tab.tabStackName)
        guard let owner = tab.coordinatorName else {
            return name
        }
        return "\(name) \(dot) \(owner)"
    }

    /// A stack's screens, one per line, then what it presents.
    private func stackRows(_ stack: StackRouter, prefix: String) -> [Row] {
        let screens = VisibleScreen.level(of: stack).screens
        let presented = stack.presentedNode as? StackRouter
        let screenRows = screens.enumerated().map { index, screen in
            let isLast = index == screens.count - 1 && presented == nil
            let key = current
            let isCurrent = key?.flow == stack.flowID && key?.index == index
            let text = prefix + corner(isLast: isLast) + " " + Self.label(of: screen, naming: naming)
            return Row(text: text, isCurrent: isCurrent)
        }
        guard let presented else {
            return screenRows
        }
        return screenRows + presentedRows(presented, by: stack, prefix: prefix, branch: corner(isLast: true))
    }

    /// `└ ⧉ full screen · CheckoutCoordinator`, then the presented stack's screens.
    private func presentedRows(
        _ presented: StackRouter,
        by presenter: any TreeNode,
        prefix: String,
        branch: String
    ) -> [Row] {
        let style = (presenter as? any PresentingRouter)?.workingPresentation?.style
        let styleText = style?.isFullScreenCover == true ? "full screen" : "sheet"
        let mark = symbols ? "⧉" : "[]"
        let text = "\(prefix)\(branch) \(mark) \(styleText) \(dot) \(Self.owner(of: presented))"
        let head = Row(text: text, isCurrent: false)
        return [head] + stackRows(presented, prefix: prefix + "    ")
    }

    /// `A › B`, or `A › … › D (4 screens)` for more than two screens.
    private func shortened(_ labels: [String]) -> String {
        let separator = symbols ? " › " : " > "
        guard labels.count > 2, let first = labels.first, let last = labels.last else {
            return labels.joined(separator: separator)
        }
        let gap = symbols ? "…" : "..."
        return [first, gap, last].joined(separator: separator) + " (\(labels.count) screens)"
    }

    /// Every screen of a stack, as the box calls them.
    private func screenLabels(of stack: StackRouter) -> [String] {
        VisibleScreen.level(of: stack).screens.map { screen in
            Self.label(of: screen, naming: naming)
        }
    }

    /// `└` for the last branch, `├` for the others.
    private func corner(isLast: Bool) -> String {
        guard symbols else {
            return isLast ? "`-" : "|-"
        }
        return isLast ? "└" : "├"
    }

    /// `·`, or `|` without symbols.
    private var dot: String {
        symbols ? "·" : "|"
    }
}
