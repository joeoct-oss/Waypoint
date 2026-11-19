//
//  LogConfiguration.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// How a whole router tree logs. Give it once to the root router, in its
/// ``NavigationConfiguration``; every router in the tree uses it, and there is no global logger,
/// so parallel tests don't share one.
///
/// ```swift
/// let logging = LogConfiguration(
///     handler: myHandler,
///     minimumLevel: .debug,
///     treeLogging: .changedStacks
/// )
/// let router = StackRouter(configuration: NavigationConfiguration(logging: logging))
/// ```
///
/// Conformances:
/// - `Sendable`, so the configuration can be built anywhere and shared with the whole tree.
public struct LogConfiguration: Sendable {
    /// Notices, errors and faults in every category, with private values hidden, written to the
    /// platform's default handler (see ``usesDefaultHandler``).
    public static var `default`: LogConfiguration {
        LogConfiguration()
    }

    /// Nothing is logged, not even by a renderer, and no message is built.
    public static var disabled: LogConfiguration {
        LogConfiguration(handler: DisabledLogHandler())
    }

    /// Where messages go.
    public let handler: any LogHandler

    /// Whether the app gave no handler, so the tree writes to the platform's default: the
    /// unified log once a SwiftUI or UIKit renderer draws it, and nowhere with `WaypointCore`
    /// alone. A handler given in the initializer or ``withHandler(_:)``, including
    /// `DisabledLogHandler` in ``disabled``, is always kept.
    public let usesDefaultHandler: Bool

    /// The least important level that is written. Default: `.notice`.
    public let minimumLevel: LogLevel

    /// The categories that are written, or `nil` for all. Default: all.
    public let categories: Set<LogCategory>?

    /// Whether route field values are written as they are, instead of `<private>` or `…`. Turn it
    /// on in debug builds only. Default: `false`.
    public let revealsPrivateValues: Bool

    /// How lines are written: readable sentences, or structured `key=value` lines for tools.
    /// Default: `.readable`.
    public let format: LogFormat

    /// Whether readable lines start with a symbol, such as `▸` for a push, and join routes with
    /// `›`. Turn it off for consoles that can't show them. Default: `true`.
    public let usesSymbols: Bool

    /// Which part of the tree is logged after each change, at `.info`. Default: `.off`.
    public let treeLogging: TreeLogging

    /// Creates a configuration. Every argument has a default.
    ///
    /// - Parameter handler: Where messages go, or `nil` for the platform's default: the unified
    ///   log once a SwiftUI or UIKit renderer draws the tree, and nowhere with `WaypointCore`
    ///   alone. Default: `nil`.
    public init(
        handler: (any LogHandler)? = nil,
        minimumLevel: LogLevel = .notice,
        categories: Set<LogCategory>? = nil,
        revealsPrivateValues: Bool = false,
        format: LogFormat = .readable,
        usesSymbols: Bool = true,
        treeLogging: TreeLogging = .off
    ) {
        self.init(
            handler: handler ?? DisabledLogHandler(),
            usesDefaultHandler: handler == nil,
            minimumLevel: minimumLevel,
            categories: categories,
            revealsPrivateValues: revealsPrivateValues,
            format: format,
            usesSymbols: usesSymbols,
            treeLogging: treeLogging
        )
    }

    /// Creates a configuration from every field, so the `with…` functions keep whether the
    /// handler is the default.
    private init(
        handler: any LogHandler,
        usesDefaultHandler: Bool,
        minimumLevel: LogLevel,
        categories: Set<LogCategory>?,
        revealsPrivateValues: Bool,
        format: LogFormat,
        usesSymbols: Bool,
        treeLogging: TreeLogging
    ) {
        self.handler = handler
        self.usesDefaultHandler = usesDefaultHandler
        self.minimumLevel = minimumLevel
        self.categories = categories
        self.revealsPrivateValues = revealsPrivateValues
        self.format = format
        self.usesSymbols = usesSymbols
        self.treeLogging = treeLogging
    }

    /// The same configuration, writing to another handler.
    public func withHandler(_ handler: any LogHandler) -> LogConfiguration {
        LogConfiguration(
            handler: handler,
            usesDefaultHandler: false,
            minimumLevel: minimumLevel,
            categories: categories,
            revealsPrivateValues: revealsPrivateValues,
            format: format,
            usesSymbols: usesSymbols,
            treeLogging: treeLogging
        )
    }

    /// The same configuration, writing from another level up.
    public func withMinimumLevel(_ level: LogLevel) -> LogConfiguration {
        LogConfiguration(
            handler: handler,
            usesDefaultHandler: usesDefaultHandler,
            minimumLevel: level,
            categories: categories,
            revealsPrivateValues: revealsPrivateValues,
            format: format,
            usesSymbols: usesSymbols,
            treeLogging: treeLogging
        )
    }

    /// The same configuration, writing other categories, or all of them for `nil`.
    public func withCategories(_ categories: Set<LogCategory>?) -> LogConfiguration {
        LogConfiguration(
            handler: handler,
            usesDefaultHandler: usesDefaultHandler,
            minimumLevel: minimumLevel,
            categories: categories,
            revealsPrivateValues: revealsPrivateValues,
            format: format,
            usesSymbols: usesSymbols,
            treeLogging: treeLogging
        )
    }

    /// The same configuration, with route field values revealed or hidden.
    public func withPrivateValuesRevealed(_ reveals: Bool) -> LogConfiguration {
        LogConfiguration(
            handler: handler,
            usesDefaultHandler: usesDefaultHandler,
            minimumLevel: minimumLevel,
            categories: categories,
            revealsPrivateValues: reveals,
            format: format,
            usesSymbols: usesSymbols,
            treeLogging: treeLogging
        )
    }

    /// The same configuration, writing lines in another format.
    public func withFormat(_ format: LogFormat) -> LogConfiguration {
        LogConfiguration(
            handler: handler,
            usesDefaultHandler: usesDefaultHandler,
            minimumLevel: minimumLevel,
            categories: categories,
            revealsPrivateValues: revealsPrivateValues,
            format: format,
            usesSymbols: usesSymbols,
            treeLogging: treeLogging
        )
    }

    /// The same configuration, with or without the readable format's symbols.
    public func withSymbols(_ usesSymbols: Bool) -> LogConfiguration {
        LogConfiguration(
            handler: handler,
            usesDefaultHandler: usesDefaultHandler,
            minimumLevel: minimumLevel,
            categories: categories,
            revealsPrivateValues: revealsPrivateValues,
            format: format,
            usesSymbols: usesSymbols,
            treeLogging: treeLogging
        )
    }

    /// The same configuration, logging more or less of the tree after each change.
    public func withTreeLogging(_ treeLogging: TreeLogging) -> LogConfiguration {
        LogConfiguration(
            handler: handler,
            usesDefaultHandler: usesDefaultHandler,
            minimumLevel: minimumLevel,
            categories: categories,
            revealsPrivateValues: revealsPrivateValues,
            format: format,
            usesSymbols: usesSymbols,
            treeLogging: treeLogging
        )
    }

    /// Whether a message of this level and category would be written.
    public func isEnabled(level: LogLevel, category: LogCategory) -> Bool {
        guard level >= minimumLevel else {
            return false
        }
        guard categories?.contains(category) ?? true else {
            return false
        }
        return handler.isEnabled(level: level, category: category)
    }

    /// Whether intervals of this category are measured: the category is written at the minimum
    /// level.
    public func measuresIntervals(in category: LogCategory) -> Bool {
        isEnabled(level: minimumLevel, category: category)
    }
}
