//
//  NavigationFlow.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// A marker for a group of screens with one job, such as checkout.
///
/// A route that names its flow can only be pushed through that flow's navigator. A coordinator
/// can be its own flow type, or you can declare an empty enum.
public protocol NavigationFlow { }

/// The flow of routes that don't declare one. They can be pushed anywhere.
///
/// Conformances:
/// - `NavigationFlow`, so routes can name it as their flow.
public enum AnyFlow: NavigationFlow { }
