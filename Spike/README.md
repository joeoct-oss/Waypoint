# Renderer spike (#72)

Throwaway prototype. Never merged into `main`.

```bash
cd Spike
tuist generate --no-open
xcodebuild test -project RendererSpike.xcodeproj -scheme RendererSpike -destination 'platform=iOS Simulator,name=waypoint-01'
```

Each UI test prints `FINDING` lines with the router state, the visible title and the screen appear log.
