# ``WaypointCore``

The UI-agnostic navigation state engine behind Waypoint.

## Overview

WaypointCore holds navigation state as plain, observable Swift values: stacks, presentations and tabs. It has no SwiftUI or UIKit code, so it builds and tests on Linux. The `Waypoint` (SwiftUI) and `WaypointUIKit` renderers turn that state into screens.

## Topics

The topics are filled in when the public API is designed.
