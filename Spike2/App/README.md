# Second-assessment spikes A, D, E and F

Throwaway prototype. Never merged into `main`. Spike C (flow routes) is the Swift package in `../FlowRoutes`.

```bash
cd Spike2/App
tuist generate --no-open
xcodebuild test -project ProposalSpike.xcodeproj -scheme ProposalSpike -destination 'platform=iOS Simulator,name=waypoint-01'
```

The app picks a scenario from its launch arguments (`-scenario a|d|e|f`). Each UI test prints `FINDING` lines.
