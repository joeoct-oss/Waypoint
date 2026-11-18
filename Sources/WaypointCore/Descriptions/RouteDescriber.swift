//
//  RouteDescriber.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// Builds a route's description from its type and fields, ignoring any `description` the route
/// declares, so a custom description can't leak a field.
///
/// - A struct prints `ProductRoute(id: <private>)`, or `CartRoute` with no fields.
/// - An enum case prints `CheckoutStep.payment`, or `CheckoutStep.card(<private>)` with a payload.
/// - A ``RouteHint`` field is left out, even when private values are revealed.
/// - Field values are `<private>` unless the field is in ``Route/publicLogFields`` or private
///   values are revealed.
enum RouteDescriber {
    /// Which field values may be shown.
    struct Visibility {
        /// Fields the route marks as public.
        let publicFields: Set<String>

        /// Whether every value is shown.
        let revealsAll: Bool

        /// Whether a field's value may be shown.
        func shows(_ label: String?) -> Bool {
            guard !revealsAll else {
                return true
            }
            guard let label else {
                return false
            }
            return publicFields.contains(label)
        }
    }

    /// The text that stands in for a private value.
    static let redacted = "<private>"

    /// The description of one route.
    static func describe<R: Route>(_ route: R, revealingPrivateValues: Bool) -> String {
        let mirror = Mirror(reflecting: route)
        let typeName = R.routeKey.typeName
        let visible = Visibility(publicFields: R.publicLogFields, revealsAll: revealingPrivateValues)
        if mirror.displayStyle == .enum {
            return describeCase(of: route, mirror: mirror, typeName: typeName, visibility: visible)
        }
        return describeFields(describedFields(of: mirror), typeName: typeName, visibility: visible)
    }

    /// A struct route's fields, without its hints, which are never described.
    static func describedFields(of mirror: Mirror) -> [Mirror.Child] {
        mirror.children.filter { child in
            !(child.value is any RouteHintField)
        }
    }

    /// `TypeName(field: value, ...)`, or `TypeName` with no fields.
    private static func describeFields(
        _ children: [Mirror.Child],
        typeName: String,
        visibility: Visibility
    ) -> String {
        let fields = children.map { child in
            describeField(label: child.label, value: child.value, visibility: visibility)
        }
        guard !fields.isEmpty else {
            return typeName
        }
        return "\(typeName)(\(fields.joined(separator: ", ")))"
    }

    /// `TypeName.case`, or `TypeName.case(payload)`.
    private static func describeCase(
        of route: some Route,
        mirror: Mirror,
        typeName: String,
        visibility: Visibility
    ) -> String {
        guard let payload = mirror.children.first, let caseName = payload.label else {
            return "\(typeName).\(caseNameWithoutPayload(route))"
        }
        let payloadMirror = Mirror(reflecting: payload.value)
        guard payloadMirror.displayStyle == .tuple else {
            let value = describeValue(payload.value, shown: visibility.shows(caseName))
            return "\(typeName).\(caseName)(\(value))"
        }
        let fields = payloadMirror.children.map { child in
            describeField(label: tupleLabel(child.label), value: child.value, visibility: visibility)
        }
        return "\(typeName).\(caseName)(\(fields.joined(separator: ", ")))"
    }

    /// The name of a case with no payload.
    ///
    /// When the route declares its own description, the case name can't be read safely, so it
    /// prints `case`.
    private static func caseNameWithoutPayload(_ route: some Route) -> String {
        guard !(route is CustomStringConvertible), !(route is CustomDebugStringConvertible) else {
            return "case"
        }
        return String(describing: route)
    }

    /// `label: value`, or `value` for an unlabelled tuple element.
    private static func describeField(label: String?, value: Any, visibility: Visibility) -> String {
        let text = describeValue(value, shown: visibility.shows(label))
        guard let label else {
            return text
        }
        return "\(label): \(text)"
    }

    /// A tuple element's label, or `nil` for the positional labels `.0`, `.1` and so on.
    static func tupleLabel(_ label: String?) -> String? {
        guard let label, !label.hasPrefix(".") else {
            return nil
        }
        return label
    }

    /// A value, or `<private>`.
    private static func describeValue(_ value: Any, shown: Bool) -> String {
        guard shown else {
            return redacted
        }
        return format(value)
    }

    /// A shown value: strings in quotes, optionals unwrapped, everything else as Swift prints it.
    private static func format(_ value: Any) -> String {
        if let string = value as? String {
            return "\"\(string)\""
        }
        let mirror = Mirror(reflecting: value)
        guard mirror.displayStyle == .optional else {
            return String(describing: value)
        }
        guard let wrapped = mirror.children.first else {
            return "nil"
        }
        return format(wrapped.value)
    }
}
