# Repository Guidelines

## Project Overview

NeverSleep is a brand-new **macOS SwiftUI** application (Xcode template scaffold, created 2026-08-03). Bundle ID: `Stillflaw.NeverSleep`. There is no product logic yet — the app renders the stock “Hello, world!” globe screen. No README, SPM packages, CI, scripts, or docs exist beyond this file.

Treat this as a greenfield macOS app, **not** iOS and **not** a SwiftPM package.

## Architecture & Data Flow

Minimal single-target SwiftUI app:

```
@main NeverSleepApp (App)
  └─ WindowGroup
       └─ ContentView (View)
```

- **Entry**: `NeverSleep/NeverSleepApp.swift` — `@main struct NeverSleepApp: App` with one `WindowGroup`.
- **UI**: `NeverSleep/ContentView.swift` — plain `View` + `#Preview`; no state, navigation, or services.
- **Resources**: `NeverSleep/Assets.xcassets` (AppIcon, AccentColor placeholders).
- **No DI, networking, persistence, or shared modules yet.** Prefer SwiftUI-native patterns (`@State` / `@Observable` / environment) when adding structure; keep app logic out of the `@main` App type unless it is truly app-scoped.

Targets (all folder-synced via `PBXFileSystemSynchronizedRootGroup`):

| Target | Role |
|--------|------|
| `NeverSleep` | macOS application |
| `NeverSleepTests` | Unit tests (Swift Testing), hosted in the app |
| `NeverSleepUITests` | UI tests (XCTest / XCUIApplication) |

New `.swift` files placed under a target folder are **auto-included** — do not hand-edit `project.pbxproj` just to add sources.

## Key Directories

```
NeverSleep/                 # App sources + Assets.xcassets
NeverSleepTests/            # Unit tests (Swift Testing)
NeverSleepUITests/          # UI / launch tests (XCTest)
NeverSleep.xcodeproj/       # Xcode project (sole build config source)
```

No `Package.swift`, `scripts/`, `docs/`, `.github/`, or shared `.xcscheme` on disk (scheme `NeverSleep` is Xcode-autocreated).

## Development Commands

Requires **Xcode 26.6+** on a host that can target **macOS 26.5**.

```bash
# Build (default configuration is Release if -configuration omitted)
xcodebuild -project NeverSleep.xcodeproj -scheme NeverSleep -configuration Debug build

# Unit + UI tests (macOS destination)
xcodebuild test -project NeverSleep.xcodeproj -scheme NeverSleep -destination 'platform=macOS'

# Coverage (not enabled in project settings; opt in per run)
xcodebuild test -project NeverSleep.xcodeproj -scheme NeverSleep -destination 'platform=macOS' -enableCodeCoverage YES
```

Open in Xcode: `open NeverSleep.xcodeproj`.

There is **no** `swift test`, npm/bun, Makefile, or linter CLI. Formatting/linting is whatever Xcode applies; no SwiftLint / swift-format config.

## Code Conventions & Common Patterns

- **Language**: Swift 5.0 mode with modern concurrency flags:
  - `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
  - `SWIFT_APPROACHABLE_CONCURRENCY = YES`
  - `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES`
- **UI**: SwiftUI only so far. Keep views small; use `#Preview` on new views.
- **Naming**: Types `UpperCamelCase`, methods/properties `lowerCamelCase`. Match existing file headers (`//  Created by Melse on …`).
- **Indentation**: 4 spaces (template default).
- **Info.plist**: generated (`GENERATE_INFOPLIST_FILE = YES`) — set keys via build settings, not a checked-in plist.
- **Localization**: string catalogs preferred (`LOCALIZATION_PREFERS_STRING_CATALOGS = YES`); use `.xcstrings` when adding copy.
- **Sandbox**: App Sandbox on; user-selected files readonly. Request entitlements deliberately when adding file/network access.
- **Errors / async**: no established error layer yet. Prefer typed `throws` + Swift Testing `#expect(throws:)`; mark UI-touching test code `@MainActor` when needed.
- **Dependencies**: none. Prefer system frameworks; if SPM is added later, wire it through the Xcode project (not a root `Package.swift` app target unless the project intentionally migrates).

## Important Files

| Path | Why it matters |
|------|----------------|
| `NeverSleep/NeverSleepApp.swift` | `@main` entry / scene graph |
| `NeverSleep/ContentView.swift` | Root UI |
| `NeverSleep/Assets.xcassets/` | Icons & accent color |
| `NeverSleep.xcodeproj/project.pbxproj` | Targets, bundle IDs, deployment, sandbox, Swift flags |
| `NeverSleepTests/NeverSleepTests.swift` | Unit test template (`import Testing`) |
| `NeverSleepUITests/*.swift` | UI + launch test templates |

Bundle IDs: `Stillflaw.NeverSleep`, `Stillflaw.NeverSleepTests`, `Stillflaw.NeverSleepUITests`. Version: marketing `1.0` / project `1`.

## Runtime/Tooling Preferences

- **Platform**: macOS only (`SDKROOT = macosx`, `MACOSX_DEPLOYMENT_TARGET = 26.5`).
- **IDE / build**: Xcode / `xcodebuild` — not SwiftPM CLI as the app driver.
- **Signing**: Automatic.
- **No package manager in use**; no Docker/CI.
- **Git hygiene gap**: no `.gitignore` yet — avoid committing `xcuserdata/`, `DerivedData/`, `.DS_Store`, or build products. Prefer adding a standard Xcode `.gitignore` before substantial work.

## Testing & QA

Two stacks — keep them distinct:

1. **Unit (`NeverSleepTests`)** — [Swift Testing](https://developer.apple.com/documentation/testing):
   - `import Testing`, `@testable import NeverSleep`
   - `@Test func …` + `#expect(…)`
   - Add new test files under `NeverSleepTests/`; they sync into the target automatically.

2. **UI (`NeverSleepUITests`)** — XCTest:
   - `XCUIApplication().launch()`, `continueAfterFailure = false`
   - Launch screenshots via `XCTAttachment` in `NeverSleepUITestsLaunchTests`
   - Annotate UI test methods `@MainActor` as in the template

Current tests are placeholders (empty unit body; UI only launches). No fixtures, mocks, or coverage thresholds. Run via the `xcodebuild test` command above; interpret results from the `.xcresult` bundle when needed (`xcrun xccov` after `-enableCodeCoverage YES`).

## Agent skills

### Issue tracker

GitHub Issues via the `gh` CLI (add a `origin` remote when ready). See `docs/agents/issue-tracker.md`.

### Triage labels

Canonical defaults: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: root `CONTEXT.md` + `docs/adr/`. See `docs/agents/domain.md`.

