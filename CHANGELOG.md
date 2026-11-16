# Changelog

All notable changes to Waypoint are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/).

## Unreleased

### Added

- Swift package with three products: `WaypointCore` (UI-agnostic state engine), `Waypoint` (SwiftUI renderer) and `WaypointUIKit` (UIKit renderer). (#2)
- `scripts/test-linux.sh` runs the core build and tests on Linux, after `scripts/check-core-imports.sh` checks that `WaypointCore` imports only Foundation, Observation and Synchronization. `CONTRIBUTING.md` explains how to run them. (#35)
