//
//  RouteDescriber+Readable.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// Readable route names for the console: `ProductListRoute(category: "shoes")` reads as
/// `Product list (…)`, with public fields shown and private ones folded into `…`.
extension RouteDescriber {
    /// `Product list` from `ProductListRoute`: the last name part, without a `Route` suffix,
    /// split into words. Acronyms such as `FAQ` keep their capitals.
    static func readableTypeName(_ typeName: String) -> String {
        let last = typeName.split(separator: ".").last.map(String.init) ?? typeName
        let trimmed = last.hasSuffix("Route") && last.count > 5 ? String(last.dropLast(5)) : last
        let words = splitWords(trimmed)
        guard let first = words.first else {
            return trimmed
        }
        let rest = words.dropFirst().map(lowercasedUnlessAcronym)
        return ([first] + rest).joined(separator: " ")
    }

    /// The readable description of one route.
    static func readable<R: Route>(_ route: R, revealingPrivateValues: Bool) -> String {
        let mirror = Mirror(reflecting: route)
        let visible = Visibility(publicFields: R.publicLogFields, revealsAll: revealingPrivateValues)
        let name = readableTypeName(R.routeKey.typeName)
        if mirror.displayStyle == .enum {
            return readableCase(of: route, mirror: mirror, name: name, visibility: visible)
        }
        return readableFields(describedFields(of: mirror), name: name, visibility: visible)
    }

    /// What follows a route's name in the journey: the values of its public fields after a
    /// space, such as `3` for `ProductRoute(id: 3)`, or an enum route's case after a colon, such
    /// as `payment` for `CheckoutStep.payment`. `nil` for a struct route with no public field.
    static func screenDetail(_ route: any Route) -> (text: String, separator: String)? {
        screenDetail(of: route)
    }

    /// The journey detail of a route of a known type.
    private static func screenDetail<R: Route>(of route: R) -> (text: String, separator: String)? {
        let mirror = Mirror(reflecting: route)
        if mirror.displayStyle == .enum {
            let caseName = mirror.children.first?.label ?? readableCaseName(route)
            return (caseName, ": ")
        }
        let publicFields = describedFields(of: mirror).filter { child in
            child.label.map(R.publicLogFields.contains) ?? false
        }
        let values = publicFields.map { child in
            readableValue(child.value)
        }
        guard !values.isEmpty else {
            return nil
        }
        return (values.joined(separator: " "), " ")
    }

    /// `Name`, `Name (id: 42)`, `Name (id: 42, …)` or `Name (…)`.
    private static func readableFields(
        _ children: [Mirror.Child],
        name: String,
        visibility: Visibility
    ) -> String {
        guard !children.isEmpty else {
            return name
        }
        let shown = children.filter { visibility.shows($0.label) }
        let fields = shown.map { child in
            readableField(label: child.label, value: child.value)
        }
        let hidden = shown.count < children.count ? ["…"] : []
        return "\(name) (\((fields + hidden).joined(separator: ", ")))"
    }

    /// `Name: case`, or `Name: case (…)` with a payload.
    private static func readableCase(
        of route: some Route,
        mirror: Mirror,
        name: String,
        visibility: Visibility
    ) -> String {
        guard let payload = mirror.children.first, let caseName = payload.label else {
            return "\(name): \(readableCaseName(route))"
        }
        let payloadMirror = Mirror(reflecting: payload.value)
        guard payloadMirror.displayStyle == .tuple else {
            let fields = [Mirror.Child(label: caseName, value: payload.value)]
            return readableFields(fields, name: "\(name): \(caseName)", visibility: visibility)
        }
        let fields = payloadMirror.children.map { child in
            Mirror.Child(label: tupleLabel(child.label), value: child.value)
        }
        return readableFields(fields, name: "\(name): \(caseName)", visibility: visibility)
    }

    /// The name of a case with no payload, or `case` when it can't be read safely.
    private static func readableCaseName(_ route: some Route) -> String {
        let structured = describe(route, revealingPrivateValues: false)
        return structured.split(separator: ".").last.map(String.init) ?? "case"
    }

    /// `label: value`, or `value` for an unlabelled tuple element. Strings print without quotes.
    private static func readableField(label: String?, value: Any) -> String {
        let text = readableValue(value)
        guard let label else {
            return text
        }
        return "\(label): \(text)"
    }

    /// A shown value: strings as they are, optionals unwrapped, everything else as Swift prints it.
    private static func readableValue(_ value: Any) -> String {
        if let string = value as? String {
            return string
        }
        let mirror = Mirror(reflecting: value)
        guard mirror.displayStyle == .optional else {
            return String(describing: value)
        }
        guard let wrapped = mirror.children.first else {
            return "nil"
        }
        return readableValue(wrapped.value)
    }

    /// `ProductList` → `["Product", "List"]`, `FAQSection` → `["FAQ", "Section"]`.
    private static func splitWords(_ name: String) -> [String] {
        let characters = Array(name)
        let breaks = characters.indices.filter { index in
            isWordStart(characters, at: index)
        }
        let ends = breaks.dropFirst() + [characters.count]
        let bounds = zip(breaks, ends)
        return bounds.map { start, end in
            String(characters[start..<end])
        }
    }

    /// Whether a new word starts at `index`: the first letter, an upper-case letter after a
    /// lower-case letter or digit, or the last capital of an acronym followed by lower case.
    private static func isWordStart(_ characters: [Character], at index: Int) -> Bool {
        guard index > 0 else {
            return true
        }
        let current = characters[index]
        let previous = characters[index - 1]
        guard current.isUppercase else {
            return false
        }
        guard previous.isUppercase else {
            return true
        }
        let next = index + 1 < characters.count ? characters[index + 1] : nil
        return next?.isLowercase ?? false
    }

    /// `List` → `list`, but `FAQ` stays `FAQ`.
    private static func lowercasedUnlessAcronym(_ word: String) -> String {
        let isAcronym = word.count > 1 && word.allSatisfy(\.isUppercase)
        return isAcronym ? word : word.lowercased()
    }
}
