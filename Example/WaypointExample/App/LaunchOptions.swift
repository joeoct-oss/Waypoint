//
//  LaunchOptions.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Foundation

// What the launch arguments ask for: start from a fresh install, start signed in, open the
// Navigation Lab, open one of its entries, or keep the splash up longer. UI tests use them to start
// a journey or open any Lab entry directly. `startingOver()` gives the options for starting a
// window over after Clear all data: the same splash, and no screen opened directly.
struct LaunchOptions {
    private static let defaultSplashDuration = Duration.seconds(1)

    let clearsData: Bool
    let signsIn: Bool
    let opensLab: Bool
    let branch: Branch?
    let entry: FlowEntry?
    let splashDuration: Duration

    init(defaults: UserDefaults) {
        let branch = Self.value(Branch.self, for: .branch, in: defaults)
        let flow = Self.value(ExampleFlow.self, for: .flow, in: defaults)
        let kind = Self.value(FlowKind.self, for: .kind, in: defaults)
        let opensLab = defaults.bool(forKey: LaunchArgument.lab.rawValue) || branch != nil
        clearsData = defaults.bool(forKey: LaunchArgument.clearData.rawValue)
        signsIn = defaults.bool(forKey: LaunchArgument.signedIn.rawValue)
        self.opensLab = opensLab
        self.branch = branch
        entry = Self.makeEntry(
            branch: branch,
            flow: flow,
            kind: kind
        )
        splashDuration = Self.makeSplashDuration(in: defaults)
    }

    private init(splashDuration: Duration) {
        clearsData = false
        signsIn = false
        opensLab = false
        branch = nil
        entry = nil
        self.splashDuration = splashDuration
    }

    // Conformances:
    // - `Value: RawRepresentable` with `String` raw values, so a launch argument's text can name a
    //   case.
    private static func value<Value: RawRepresentable>(
        _ type: Value.Type,
        for argument: LaunchArgument,
        in defaults: UserDefaults
    ) -> Value? where Value.RawValue == String {
        defaults.string(forKey: argument.rawValue).flatMap(Value.init(rawValue:))
    }

    private static func makeSplashDuration(in defaults: UserDefaults) -> Duration {
        let seconds = defaults.double(forKey: LaunchArgument.splashSeconds.rawValue)
        guard seconds > 0 else {
            return defaultSplashDuration
        }
        return .seconds(seconds)
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

    func startingOver() -> LaunchOptions {
        LaunchOptions(splashDuration: splashDuration)
    }
}
