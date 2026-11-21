# Renderer spike (#250)

Throwaway spike code. This branch is never merged.

It runs the same stack scenarios through a SwiftUI stack renderer and a UIKit stack renderer, and checks the SwiftUI environment and screen chrome inside the UIKit renderer. The results are in the planning repo: `docs/spike/250-stack-renderers-findings.md` and plan 250.

- `tuist generate` builds the Xcode project and workspace.
- `run.sh <renderer> <simulator-id> <label> <runs> <tests…>` runs UI tests and prints one line per test. Logs go to `runs/`.
- `resume.sh` and `run02.sh` are the exact scripts used for the iOS 17.5 runs. They have that Mac's simulator ids hard-coded.
- The code still has the debug aids used for the hand-checks: an `NSLog` on the SwiftUI binding's setter, `testZDump`, and the `-autopush`, `-autoToolbar` and `-supplementBack` launch arguments.
