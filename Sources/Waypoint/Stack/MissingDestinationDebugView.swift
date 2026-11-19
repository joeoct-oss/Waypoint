//
//  MissingDestinationDebugView.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

#if canImport(SwiftUI) && DEBUG
    import SwiftUI
    import WaypointCore

    /// The debug screen for a route with no destination in its stack: it names the route type,
    /// says why the push still went ahead, and shows the line that fixes it.
    ///
    /// Only debug builds have it. It names the route's type, never its field values.
    struct MissingDestinationDebugView: View {
        /// The accessibility identifier of the screen's title, for UI tests.
        static let titleIdentifier = "waypoint.missingDestination.title"

        /// The route with no destination.
        let missing: MissingDestination

        /// The screen.
        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    explanation
                    fix
                    footer
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationTitle("No destination")
        }

        /// The warning sign and the title naming the route type.
        private var header: some View {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                Text("No destination for \(missing.routeTypeName)")
                    .font(.title2.bold())
                    .accessibilityIdentifier(Self.titleIdentifier)
            }
        }

        /// Why the screen is empty, and why the push still went ahead.
        private var explanation: some View {
            Text(
                "No screen inside this stack registered a destination for \(missing.routeTypeName). "
                    + "The router knows the type, because another stack registered it or the root's "
                    + "NavigationConfiguration lists it, so the push went ahead."
            )
            .font(.body)
        }

        /// The line that fixes it, and where it goes.
        private var fix: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Fix")
                    .font(.headline)
                Text(".destination(\(missing.routeTypeName).self) { route in\n    …\n}")
                    .font(.system(.callout, design: .monospaced))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    .textSelection(.enabled)
                Text("Add it to the stack's first screen, or to a screen pushed before this one.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }

        /// The reported issue, and what other builds show.
        private var footer: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(missing.issue.description)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text(
                    "Debug builds only. Release builds show a blank screen and log the issue. "
                        + "Choose your own screen with .missingDestination { }."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }
#endif
