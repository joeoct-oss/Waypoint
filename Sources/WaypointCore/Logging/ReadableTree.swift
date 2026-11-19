//
//  ReadableTree.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// One flow of the readable tree and the flows inside it.
///
/// ```text
/// tabs      home · [shop] · profile
/// ├ home    root
/// ├ shop    Product list (…) › Product (id: 42, …)
/// │ └ sheet checkout  Checkout (…) › Address (…)
/// └ profile root
/// ```
struct ReadableTree {
    /// The flow's name, such as `shop` or `sheet checkout`.
    let name: String

    /// What the flow shows, such as `Product list (…)`.
    let detail: String

    /// The flows inside this one, in order.
    let children: [ReadableTree]

    /// The tree, one flow per line, with the details lined up in one column.
    var rendered: String {
        let rows = [(head: name, detail: detail)] + childRows(prefix: "")
        let width = max(ReadableLog.flowWidth, rows.map(\.head.count).max() ?? 0)
        return rows.map { row in
            "\(row.head.padding(toLength: width, withPad: " ", startingAt: 0)) \(row.detail)"
        }.joined(separator: "\n")
    }

    /// The same tree, its name starting with how it is presented, such as `sheet checkout`.
    func presented(as style: PresentationStyle?) -> ReadableTree {
        guard let style else {
            return self
        }
        return ReadableTree(name: "\(style) \(name)", detail: detail, children: children)
    }

    /// The rows of the children, each name behind its branch.
    private func childRows(prefix: String) -> [(head: String, detail: String)] {
        children.enumerated().flatMap { index, child in
            let isLast = index == children.count - 1
            let branch = prefix + (isLast ? "└ " : "├ ")
            let below = prefix + (isLast ? "  " : "│ ")
            return [(head: branch + child.name, detail: child.detail)] + child.childRows(prefix: below)
        }
    }
}
