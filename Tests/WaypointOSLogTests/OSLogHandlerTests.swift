//
//  OSLogHandlerTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// Compiles empty where `os` is missing, like the target it tests. Run on a Mac.

#if canImport(os)
    import Foundation
    import os
    import Testing
    import WaypointCore
    import WaypointTestSupport

    @testable import WaypointOSLog

    /// The unified log and signpost handler (planning #328).
    @Suite("OSLog handler")
    @MainActor
    struct OSLogHandlerTests {
        @Test("Log levels map one to one to OSLog types")
        func levelsMapOneToOne() {
            #expect(OSLogHandler.osLogType(for: .debug) == .debug)
            #expect(OSLogHandler.osLogType(for: .info) == .info)
            #expect(OSLogHandler.osLogType(for: .notice) == .default)
            #expect(OSLogHandler.osLogType(for: .error) == .error)
            #expect(OSLogHandler.osLogType(for: .fault) == .fault)
        }

        @Test("The default subsystem is the bundle identifier")
        func defaultSubsystemUsesTheBundleIdentifier() {
            let expected = Bundle.main.bundleIdentifier.map { $0 + ".waypoint" } ?? "waypoint"

            #expect(OSLogHandler.defaultSubsystem == expected)
            #expect(OSLogHandler().subsystem == expected)
            #expect(OSLogHandler(subsystem: "com.example.shop").subsystem == "com.example.shop")
        }

        @Test("One channel is built per category")
        func oneChannelIsBuiltPerCategory() {
            let handler = OSLogHandler(subsystem: "com.example.waypoint-tests")

            for _ in 0..<3 {
                handler.log(Self.message(.navigation))
                handler.log(Self.message(.issues))
                handler.log(Self.message(LogCategory("checkout")))
            }

            #expect(handler.channels.builtCount == 3)
        }

        @Test("Intervals begin and end in pairs")
        func intervalsPairUp() {
            let handler = OSLogHandler(subsystem: "com.example.waypoint-tests")
            let transaction = LogInterval(name: "transaction", category: .navigation, id: 1)
            let push = LogInterval(name: "push", category: .renderer, id: 2)
            let custom = LogInterval(name: "checkout", category: LogCategory("checkout"), id: 3)

            handler.beginInterval(transaction)
            handler.beginInterval(push)
            handler.beginInterval(custom)
            #expect(handler.channels.runningCount == 3)

            handler.endInterval(push)
            handler.endInterval(transaction)
            handler.endInterval(custom)
            handler.endInterval(custom)
            #expect(handler.channels.runningCount == 0)
        }

        @Test("Signpost names are fixed")
        func signpostNamesAreFixed() {
            #expect("\(OSLogChannels.signpostName("transaction"))" == "transaction")
            #expect("\(OSLogChannels.signpostName("push"))" == "push")
            #expect("\(OSLogChannels.signpostName("checkout"))" == "interval")
        }

        @Test("The OSLog configuration keeps its settings")
        func osLogConfigurationKeepsItsSettings() {
            let logging = LogConfiguration.osLog(
                subsystem: "com.example.shop",
                minimumLevel: .debug,
                revealsPrivateValues: true
            )

            #expect((logging.handler as? OSLogHandler)?.subsystem == "com.example.shop")
            #expect(logging.minimumLevel == .debug)
            #expect(logging.revealsPrivateValues)
            #expect(!logging.usesDefaultHandler)
            #expect(LogConfiguration.osLog().minimumLevel == .notice)
        }

        @Test("Default logging installs the OSLog handler only when the app chose none")
        func defaultLoggingInstallsTheSharedHandlerOnlyForTheDefault() {
            let byDefault = StackRouter(configuration: .permissive)
            let recorder = RecordingLogHandler()
            let logging = LogConfiguration(handler: recorder)
            let chosen = StackRouter(configuration: NavigationConfiguration(logging: logging, registry: .permissive))
            let tabs = TabRouter(tabs: MainTab.homeAndShop, selection: .home)

            DefaultLogging.install(on: byDefault)
            DefaultLogging.install(on: chosen)
            DefaultLogging.install(on: tabs)

            #expect(byDefault.configuration.logging.handler is OSLogHandler)
            #expect(chosen.configuration.logging.handler is RecordingLogHandler)
            #expect(tabs.configuration.logging.handler is OSLogHandler)
        }

        /// A notice in `category`.
        private static func message(_ category: LogCategory) -> LogMessage {
            LogMessage(level: .notice, category: category, text: "test line", file: #fileID, line: #line)
        }
    }
#endif
