# ``WaypointCore``

The UI-agnostic navigation state engine behind Waypoint.

## Overview

WaypointCore holds navigation state as plain, observable Swift values: stacks, presentations and tabs. It has no SwiftUI or UIKit code, so it builds and tests on Linux. The `Waypoint` (SwiftUI) and `WaypointUIKit` renderers turn that state into screens.

## Topics

### Essentials

- <doc:Routes>
- <doc:NavigationState>
- <doc:WhyTheseConformances>

### Navigating

- <doc:StackNavigation>
- <doc:PresentingFlows>
- <doc:Tabs>

### Flows

- <doc:CoordinatorsAndChildFlows>
- <doc:RootSwitching>
- <doc:DeepLinks>
- <doc:Guards>
- <doc:StateRestoration>

### Seeing and testing what happened

- <doc:EventsAndLogging>
- <doc:Descriptions>
- <doc:TestingYourNavigation>

### Rules

- <doc:Concurrency>
