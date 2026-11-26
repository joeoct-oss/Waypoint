//
//  LaunchOptions.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCatalog
import Foundation

// What the launch arguments ask for: start from a fresh install, start signed in, open the
// Navigation Lab, open one of its entries, skip the splash or keep it up longer, push products onto
// the shop with a change mid-push, draw the product page's related link as a system link, make it
// push a route with no destination in its stack, make the Lab's demo reviews load slower, or run
// the app's animations faster. UI tests use them to start a journey or open any Lab entry directly.
// `startingOver()` gives the options for starting a window over after Clear all data: the same
// splash and animation speed, and no screen opened directly. Plain values read once, so
// `nonisolated`: a route, which is nonisolated, reads them from another module to build the Lab's
// launch path.
package nonisolated struct LaunchOptions {
    private static let defaultSplashDuration = Duration.seconds(1)
    private static let usualAnimationSpeed: Float = 1

    package let clearsData: Bool
    package let signsIn: Bool
    package let opensLab: Bool
    package let branch: Branch?
    package let entry: FlowEntry?
    package let splashDuration: Duration
    package let shopSteps: ShopLaunchSteps
    package let usesSystemLinks: Bool
    package let linksToMissingDestination: Bool
    // `nil` keeps the Lab's usual reviews delay.
    package let labReviewsDelay: Duration?
    // How fast the windows' animations run: 1 is the usual speed.
    package let animationSpeed: Float

    package init(defaults: UserDefaults) {
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
        shopSteps = ShopLaunchSteps(
            productIDs: Self.makeProductIDs(in: defaults),
            followUp: Self.value(ShopFollowUp.self, for: .shopFollowUp, in: defaults)
        )
        usesSystemLinks = defaults.bool(forKey: LaunchArgument.systemLinks.rawValue)
        linksToMissingDestination = defaults.bool(forKey: LaunchArgument.missingDestination.rawValue)
        labReviewsDelay = Self.makeLabReviewsDelay(in: defaults)
        animationSpeed = Self.makeAnimationSpeed(in: defaults)
    }

    private init(
        splashDuration: Duration,
        animationSpeed: Float
    ) {
        clearsData = false
        signsIn = false
        opensLab = false
        branch = nil
        entry = nil
        self.splashDuration = splashDuration
        shopSteps = .none
        usesSystemLinks = false
        linksToMissingDestination = false
        labReviewsDelay = nil
        self.animationSpeed = animationSpeed
    }

    // Conformances:
    // - `Value: RawRepresentable` with `String` raw values, so a launch argument's text can name a
    //   case.
    private static func value<Value: RawRepresentable>(
        _ type: Value.Type,
        for argument: LaunchArgument,
        in defaults: UserDefaults
    ) -> Value? where Value.RawValue == String {
        defaults.string(forKey: argument.rawValue).flatMap { Value(rawValue: $0) }
    }

    // No `-splashSeconds` keeps the usual splash; `-splashSeconds 0` skips it, as UI tests do.
    private static func makeSplashDuration(in defaults: UserDefaults) -> Duration {
        guard defaults.object(forKey: LaunchArgument.splashSeconds.rawValue) != nil else {
            return defaultSplashDuration
        }
        let seconds = defaults.double(forKey: LaunchArgument.splashSeconds.rawValue)
        return .seconds(max(0, seconds))
    }

    // No `-labReviewsSeconds` keeps the Lab's usual delay.
    private static func makeLabReviewsDelay(in defaults: UserDefaults) -> Duration? {
        guard defaults.object(forKey: LaunchArgument.labReviewsSeconds.rawValue) != nil else {
            return nil
        }
        let seconds = defaults.double(forKey: LaunchArgument.labReviewsSeconds.rawValue)
        return .seconds(max(0, seconds))
    }

    // No `-animationSpeed`, or a value of 0 or less, keeps the usual speed.
    private static func makeAnimationSpeed(in defaults: UserDefaults) -> Float {
        let speed = defaults.float(forKey: LaunchArgument.animationSpeed.rawValue)
        guard speed > 0 else {
            return usualAnimationSpeed
        }
        return speed
    }

    private static func makeProductIDs(in defaults: UserDefaults) -> [Int] {
        let text = defaults.string(forKey: LaunchArgument.shopPath.rawValue) ?? ""
        return text.split(separator: ",").compactMap { Int($0) }
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

    package func startingOver() -> LaunchOptions {
        LaunchOptions(
            splashDuration: splashDuration,
            animationSpeed: animationSpeed
        )
    }
}
