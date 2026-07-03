# QA Command Matrix

Assessed locally on 2026-05-02 in this workspace.

## Environment snapshot

- Active developer directory: `/Library/Developer/CommandLineTools`
- Swift: `Apple Swift version 6.3.1`
- Full Xcode app: not found under `/Applications`
- `simctl`: unavailable from the active developer directory
- `xcresulttool`: unavailable from the active developer directory
- `xctrace`: installed shim exists, but it fails until full Xcode is selected
- `xcpretty`: not installed in this shell environment
- `muter`: not installed

## Feasibility by category

| Category | Repo entrypoint | Local command | Status here | Notes / blocker |
| --- | --- | --- | --- | --- |
| SwiftPM test discovery | `Package.swift` | `swift test list --scratch-path /tmp/vpstudio-codex-spm` | Feasible | Use a custom scratch path to avoid contention with the shared `.build` lock in this workspace. |
| SwiftPM coverage | `Package.swift` | `tools/swiftpm-coverage-local.sh` | Feasible, subject to compile/test health | Runs `swift package describe`, `swift test list`, then `swift test --enable-code-coverage` with an isolated scratch dir. |
| VisionOS CI-style build/test | `.github/workflows/test.yml` | `xcodebuild build-for-testing ...` / `xcodebuild test-without-building ...` | Blocked | Current developer dir is CLT-only; `xcodebuild` requires full Xcode. Local shell also lacks `xcpretty`. |
| Visual screenshot capture | `tools/capture-explore-style.sh` | `tools/capture-explore-style.sh <stamp>` | Blocked | Script requires `xcodebuild`, `simctl`, and a bootable Vision Pro simulator runtime. |
| Deep smoke / e2e | `tools/visionpro-deep-smoke.sh` | `tools/visionpro-deep-smoke.sh` | Blocked | Script requires `xcodebuild`, `simctl`, `xcresulttool`, and a visionOS simulator device/runtime. |
| Launch/tab stress | `tools/visionpro-deep-smoke.sh` | Included in deep smoke run | Blocked | The stress loop is implemented in the script, but it depends on simulator launch/install support first. |
| Result bundle summarization | `tools/visionpro-deep-smoke.sh` | `xcrun xcresulttool ...` | Blocked | `xcresulttool` is unavailable from the active CLT-only developer dir. |
| Performance profiling | external tooling | `xctrace ...` | Blocked | `xctrace` fails until full Xcode is selected; no simulator/device target is available either. |
| Load testing | no dedicated harness found | N/A | No native harness found | Current repo-owned QA scripts focus on simulator smoke/stress, not service-level load generation. |
| Mutation testing | external tooling | `muter run` | Blocked / not configured | `muter` is not installed and no mutation harness is defined in the repo. |

## Recommended local commands

### 1. SwiftPM coverage without touching the shared `.build`

```bash
tools/swiftpm-coverage-local.sh
```

Optional narrow scope:

```bash
tools/swiftpm-coverage-local.sh --filter VPStudioTests.PlayerControlPresentationTests
```

### 2. Raw SwiftPM equivalents

```bash
swift package describe --scratch-path /tmp/vpstudio-codex-spm
swift test list --scratch-path /tmp/vpstudio-codex-spm
swift test --scratch-path /tmp/vpstudio-codex-spm --enable-code-coverage --show-code-coverage-path
```

### 3. Commands that stay blocked until full Xcode is selected

```bash
xcodebuild -version
xcrun simctl list devices available
xcrun xcresulttool --help
xctrace list devices
```

## Practical unblockers

1. Install full Xcode with the required visionOS runtime.
2. Select it with `sudo xcode-select -s /Applications/Xcode.app`.
3. Re-run:

```bash
xcodebuild -version
xcrun simctl list runtimes
xcrun simctl list devices available
```

4. If you want the workflow command exactly as written in `.github/workflows/test.yml`, install `xcpretty` locally or drop the pipe while debugging.
