//
//  NavigationConfiguration.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// The settings of a whole router tree, given once to the root router.
///
/// Every router in the tree reads the same configuration through
/// ``StackRouter/configuration`` or ``TabRouter/configuration``, and none can change it, so a
/// line in a leaf coordinator never changes the whole app. Settings for one flow, such as
/// fallbacks and presentation defaults, stay on each router.
///
/// Every field has a default, so an app passes only what it wants to change:
///
/// ```swift
/// #if DEBUG
/// let logging = LogConfiguration.default.withMinimumLevel(.debug)
/// #else
/// let logging = LogConfiguration.default
/// #endif
/// let configuration = NavigationConfiguration(
///     logging: logging,
///     onNavigationFailure: { failure in
///         crashReporter.record(failure.description)
///     }
/// )
/// let router = StackRouter(root: HomeRoute(), configuration: configuration)
/// ```
///
/// Conformances:
/// - `Sendable`, so the configuration can be built anywhere and handed to the root router.
public struct NavigationConfiguration: Sendable {
    /// Every setting at its default.
    public static var `default`: NavigationConfiguration {
        NavigationConfiguration()
    }

    /// How the whole tree logs. Default: ``LogConfiguration/default``.
    public let logging: LogConfiguration

    /// The most calls that may be queued while changes are applied, in one main-actor turn.
    /// Calls past it report `reentrantLoop`. Default: 32.
    ///
    /// A limit below 1 would drop every call made from an observer, so the root router reports
    /// `invalidSetting` and uses 32 instead.
    public let maxQueuedChanges: Int

    /// The route types known before any destination is registered, such as the ones restored
    /// navigation state needs. Renderers and coordinators add the rest as they register
    /// destinations. Default: an empty registry.
    public let registry: RouteRegistry

    /// Called on the main actor for each call anywhere in the tree that failed and could not be
    /// recovered, so the app can show a message or report it. Default: `nil`.
    public let onNavigationFailure: (@MainActor (NavigationFailure) -> Void)?

    /// Creates a configuration. Every argument has a default.
    ///
    /// - Parameters:
    ///   - logging: How the whole tree logs. Default: ``LogConfiguration/default``.
    ///   - maxQueuedChanges: The most calls queued in one main-actor turn. Default: 32.
    ///   - registry: The route types known from the start. Default: an empty registry.
    ///   - onNavigationFailure: Called for each failure that was not recovered. Default: `nil`.
    public init(
        logging: LogConfiguration = .default,
        maxQueuedChanges: Int = 32,
        registry: RouteRegistry = RouteRegistry(),
        onNavigationFailure: (@MainActor (NavigationFailure) -> Void)? = nil
    ) {
        self.logging = logging
        self.maxQueuedChanges = maxQueuedChanges
        self.registry = registry
        self.onNavigationFailure = onNavigationFailure
    }

    /// The same configuration with another registry.
    func withRegistry(_ registry: RouteRegistry) -> NavigationConfiguration {
        NavigationConfiguration(
            logging: logging,
            maxQueuedChanges: maxQueuedChanges,
            registry: registry,
            onNavigationFailure: onNavigationFailure
        )
    }

    /// The same configuration with another queue limit.
    func withMaxQueuedChanges(_ limit: Int) -> NavigationConfiguration {
        NavigationConfiguration(
            logging: logging,
            maxQueuedChanges: limit,
            registry: registry,
            onNavigationFailure: onNavigationFailure
        )
    }

    /// The configuration the tree uses, and why it differs from this one, if it does: a queue
    /// limit below 1 becomes the default.
    func validated() -> (configuration: NavigationConfiguration, problem: String?) {
        let fallbackLimit = NavigationConfiguration.default.maxQueuedChanges
        guard maxQueuedChanges >= 1 else {
            let problem = "maxQueuedChanges must be at least 1, so \(maxQueuedChanges) was not used. "
                + "The tree uses \(fallbackLimit)."
            return (withMaxQueuedChanges(fallbackLimit), problem)
        }
        return (self, nil)
    }
}
