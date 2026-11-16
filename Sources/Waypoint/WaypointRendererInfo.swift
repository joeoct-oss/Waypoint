// Waypoint is the SwiftUI renderer for WaypointCore.
//
// The whole file is guarded so the module compiles empty on platforms without SwiftUI, such as Linux.

#if canImport(SwiftUI)
    import SwiftUI
    import WaypointCore

    /// Placeholder until the SwiftUI renderer lands.
    enum WaypointRendererInfo {
        /// The name of the renderer.
        static let name = "SwiftUI"
    }
#endif
