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
/// let logging = LogConfiguration(handler: myHandler, minimumLevel: .debug, treeLogging: .changedStacks)
/// let router = StackRouter(configuration: NavigationConfiguration(logging: logging))
/// ```
///
/// Conformances:
/// - `Sendable`, so the configuration can be built anywhere and shared with the whole tree.
public struct LogConfiguration: Sendable {
    /// Notices, errors and faults in every category, with private values hidden.
    public static var `default`: LogConfiguration {
        LogConfiguration()
    }

    /// Nothing is logged and no message is built.
    public static var disabled: LogConfiguration {
        LogConfiguration(handler: DisabledLogHandler())
    }

    /// Where messages go.
    public let handler: any LogHandler

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

    /// Creates a configuration. Every argument has a default; the default handler writes
    /// nothing until a renderer or the app sets one.
    public init(
        handler: any LogHandler = DisabledLogHandler(),
        minimumLevel: LogLevel = .notice,
        categories: Set<LogCategory>? = nil,
        revealsPrivateValues: Bool = false,
        format: LogFormat = .readable,
        usesSymbols: Bool = true,
        treeLogging: TreeLogging = .off
    ) {
        self.handler = handler
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
