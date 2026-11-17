//
//  LaunchOptions.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Foundation

// What the launch arguments ask for: start signed in or as a guest, open the Navigation Lab, or open one of
// its entries.
// UI tests use them to start a journey or open any Lab entry directly.
struct LaunchOptions {
    let startMembership: Membership?
    let opensLab: Bool
    let branch: Branch?
    let entry: FlowEntry?

    init(defaults: UserDefaults) {
        let branch = Self.value(Branch.self, for: .branch, in: defaults)
        let flow = Self.value(ExampleFlow.self, for: .flow, in: defaults)
        let kind = Self.value(FlowKind.self, for: .kind, in: defaults)
        let opensLab = defaults.bool(forKey: LaunchArgument.lab.rawValue) || branch != nil
        startMembership = Self.makeMembership(
            signedIn: defaults.bool(forKey: LaunchArgument.signedIn.rawValue) || opensLab,
            guest: defaults.bool(forKey: LaunchArgument.guest.rawValue)
        )
        self.opensLab = opensLab
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

    private static func makeMembership(
        signedIn: Bool,
        guest: Bool
    ) -> Membership? {
        if signedIn {
            return .member
        }
        return guest ? .guest : nil
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
