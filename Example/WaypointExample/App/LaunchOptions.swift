//
//  LaunchOptions.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Foundation

// The screen the launch arguments ask for, such as `-branch uikit -flow sheet -kind swiftui`. UI tests use
// them to open any of the twenty entries directly.
struct LaunchOptions {
    let branch: Branch?
    let entry: FlowEntry?

    init(defaults: UserDefaults) {
        let branch = Self.value(Branch.self, for: .branch, in: defaults)
        let flow = Self.value(ExampleFlow.self, for: .flow, in: defaults)
        let kind = Self.value(FlowKind.self, for: .kind, in: defaults)
        self.branch = branch
        entry = Self.makeEntry(
            branch: branch,
            flow: flow,
            kind: kind
        )
    }

    // Conformances:
    // - `Value: RawRepresentable` with `String` raw values, so a launch argument's text can name a case.
    private static func value<Value: RawRepresentable>(
        _ type: Value.Type,
        for argument: LaunchArgument,
        in defaults: UserDefaults
    ) -> Value? where Value.RawValue == String {
        defaults.string(forKey: argument.rawValue).flatMap(Value.init(rawValue:))
    }

    private static func makeEntry(
        branch: Branch?,
        flow: ExampleFlow?,
        kind: FlowKind?
    ) -> FlowEntry? {
        guard let branch, let flow, let kind else {
            return nil
        }
        return FlowEntry(
            branch: branch,
            flow: flow,
            kind: kind
        )
    }
}
