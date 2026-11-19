//
//  ViewTypeName.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// The name of a screen's view type as people read it: `ProductDetailView`, also for a view
/// wrapped in modifiers, such as `ModifiedContent<ProductDetailView, _PaddingLayout>`.
package enum ViewTypeName {
    /// The wrappers whose first generic argument is the view that matters.
    private static let wrappers: Set<String> = [
        "ModifiedContent",
        "Optional",
        "_ConditionalContent",
        "AnyView",
        "Group",
        "TupleView",
    ]

    /// The readable name of `type`.
    package static func of(_ type: Any.Type) -> String {
        simplified(String(describing: type))
    }

    /// The view inside a wrapper's name, without a module or generic arguments.
    package static func simplified(_ name: String) -> String {
        let trimmed = name.filter { character in
            character != " "
        }
        guard let open = trimmed.firstIndex(of: "<"), trimmed.hasSuffix(">") else {
            return lastComponent(trimmed)
        }
        let base = lastComponent(String(trimmed[..<open]))
        guard wrappers.contains(base) else {
            return base
        }
        let inside = trimmed[trimmed.index(after: open)..<trimmed.index(before: trimmed.endIndex)]
        guard let first = firstArgument(of: inside) else {
            return base
        }
        return simplified(first)
    }

    /// `ProductDetailView` for `Shop.ProductDetailView`.
    private static func lastComponent(_ name: String) -> String {
        guard let dot = name.lastIndex(of: ".") else {
            return name
        }
        return String(name[name.index(after: dot)...])
    }

    /// The first argument of a generic argument list, up to its first top-level comma.
    private static func firstArgument(of list: Substring) -> String? {
        var depth = 0
        for index in list.indices {
            let character = list[index]
            if character == ",", depth == 0 {
                return String(list[..<index])
            }
            if character == "<" || character == "(" {
                depth += 1
            }
            if character == ">" || character == ")" {
                depth -= 1
            }
        }
        return list.isEmpty ? nil : String(list)
    }
}
