# Research: Read/Write API for the Display-Off Interval (display sleep)

**Ticket:** https://github.com/Melse/NeverSleep/issues/3
**Date:** 2026-08-03
**Machine:** macOS 26.5.2 (Darwin 25.5.0, build 25F84), Apple M4, no battery (desktop; `pmset -g custom` shows only an `AC Power` section). UI language is Chinese on this box; English strings cited from binaries/man pages.
**Glossary:** "display-off interval" = System Settings → Lock Screen → 不活跃时关闭显示器 ("Turn display off when inactive") — the `displaysleep` power-management setting.

## Executive answer

- **Read:** supported, no privileges needed. Run `/usr/bin/pmset -g custom` via `Process` and parse the per-source `displaysleep` value; detect battery-vs-AC via the public IOPowerSources framework. Verified working inside a real App Sandbox (ad-hoc signed, Debug-style).
- **Write:** **no supported public API exists** (no framework function, no entitlement, no doc). The only supported writer is the `pmset` CLI, which **must run as root** (verified live: non-root write exits 1 with `'pmset' must be run as root...`). The System Settings Lock Screen pane itself writes through private APIs.
- Least-bad supported write paths for NeverSleep v1, ranked below (deep link to the pane; AppleScript admin auth; SMAppService privileged helper). The private `IOPMConnection` route is explicitly labeled private and not recommended.

---

## 1. Read path and write path

### The setting

- `man pmset`: `displaysleep - display sleep timer; ... (value in minutes, or 0 to disable)`; flags `-a | -b | -c | -u` select **all / battery / charger (wall) / UPS**; **"pmset must be run as root in order to modify any settings."** ([`man pmset`](x-man-page://pmset), SETTING/SYNOPSIS sections)
- Live read on this machine: `pmset -g` → `displaysleep 60`; `pmset -g custom` → `AC Power: ... displaysleep 60`. Observed 2026-08-03.
- The System Settings Lock Screen pane shows 1小时 ("1 hour") in the 不活跃时关闭显示器 dropdown while `displaysleep` = 60 — the dropdown maps to `displaysleep` [INFERENCE: strongly supported by simultaneous observation of UI value and pmset value; not tested by changing the setting, which would modify the user's configuration].

### Read path (supported, non-root)

1. **`/usr/bin/pmset -g custom` parsed via `Process` (NSTask)** — the de-facto supported read interface. Root not needed. Per-source sections (`Battery Power:` / `AC Power:`) each contain `displaysleep` (minutes). `pmset -g` shows only the currently-in-use source plus live overrides (e.g. `sleep prevented by ...` lines). Output format is stable English key/value, but it is CLI text, not a documented API — parse defensively.
2. **IOPowerSources framework (public, sandbox-friendly)** for power-source state: `IOPSGetProvidingPowerSourceType()` → `kIOPSTypeInternalBattery` / `kIOPSTypeACPower`; `IOPSGetPowerSourceDescription()`; `IOPSGetTimeRemainingEstimate()`. Header: `MacOSX26.5.sdk/System/Library/Frameworks/IOKit.framework/Headers/ps/IOPowerSources.h` (verified present, e.g. line 317 `IOPSGetProvidingPowerSourceType`).
3. **Public IOKit PM APIs** exist for everything *except* the sleep timers: assertions, initiating sleep, scheduling wake/sleep events, battery info, sleep/wake notifications, aggressiveness factors. Full public surface enumerated from `MacOSX26.5.sdk/System/Library/Frameworks/IOKit.framework/Headers/pwr_mgt/IOPMLib.h` (read verbatim): `IOPMFindPowerManagement`, `IOPMSetAggressiveness`, `IOPMGetAggressiveness`, `IOPMSleepEnabled`, `IOPMSleepSystem`, `IOPMCopyBatteryInfo`, `IORegisterForSystemPower`, `IOAllowPowerChange`, `IOCancelPowerChange`, `IOPMSchedulePowerEvent` (+ cancel/copy), `IOPMAssertionCreateWithName/WithDescription/WithProperties`, `IOPMAssertionRelease`, `IOPMCopyAssertionsByProcess/Status`, `IOPMCopyCPUPowerStatus`, `IOPMGetThermalWarningLevel`, `IOPMAssertionDeclareUserActivity`, `IOPMDeclareNetworkClientActivity`. **No getter or setter for `displaysleep`/sleep timers exists in any public header** (grep of the whole IOKit header tree for `IOPMSetSleepSettings`, `IOPMConnection`, `displaysleep`, `IOPMSetSleepDisabled` → zero hits).
4. Not a supported read: `defaults read com.apple.EnergySaver.portable.BatteryPower` → "Domain does not exist" on this machine, and `/Library/Preferences/SystemConfiguration/com.apple.PowerManagement.plist` is absent (that storage is daemon-private). Do not read settings this way.

### Write path

- **Supported writer = `pmset` CLI, root only.** `man pmset`: "pmset must be run as root in order to modify any settings." Live verification: `pmset -a displaysleep 60` as normal user printed `'pmset' must be run as root...`, exit code 1, setting unchanged (still 60). Syntax for the interval: `pmset -a displaysleep <minutes>` (all sources), `-b` battery-only, `-c` charger-only; `0` = never.
- **How the OS itself writes it (private):** `strings /usr/bin/pmset` shows the private `IOPMConnectionCreate`/`IOPMConnectionSetNotification` transport plus `IOPMrootDomain` and `com.apple.PowerManagement.control` — these are not in the public SDK headers (verified absent). The System Settings Lock Screen pane (`/System/Library/ExtensionKit/Extensions/LockScreen.appex`) contains the private selectors `displaySleepsFor:` and `setMinutesUntilDisplaySleeps:for:` and links the private `SystemAdministration.framework`, `login.framework`, `Settings.framework`, and `libswiftIOKit` — i.e. the pane reaches powerd through private frameworks/XPC. **Label: private API; no public equivalent.**
- **macOS 26 Settings Intents do not cover it.** `LockScreenIntentsExtension.appex` (`/System/Library/ExtensionKit/Extensions/`) registers 8 intents (lock message, login-window mode/buttons, password-after-screensaver delay, large clock, password hints, open-pane deep link, and **Screen Saver start delay** via `ScreenSaverDelayEntity`) — a full scan of every system settings-intents extension's `Metadata.appintents/extract.actionsdata` found **zero** intents touching display-off/display-sleep. So "System Settings App Intents" is not a write path for this setting (it *is* for the Screen Saver delay).
- **Persistence domain (observed, private):** the pane binary references the cfprefs domain `com.apple.EnergySaver.portable.BatteryPower` for battery-side settings. These domains are powerd-owned; direct `defaults write` is unsupported and not honored (daemon cache) — do not use.

## 2. Battery vs plugged-in as separate API values

- Yes — the OS stores separate display-off intervals per power source on portables:
  - `man pmset`: `-a` all, `-b` battery, `-c` charger, `-u` UPS; the value is the same key (`displaysleep`) applied per source.
  - `pmset -g custom` prints one section per supported source (`Battery Power:` and/or `AC Power:`), each with its own `displaysleep`. This desktop only reports `AC Power:`.
  - The Lock Screen pane binary contains both UI strings `Turn display off on battery when inactive` and `Turn display off on power adapter when inactive` (extracted via `strings`), i.e. the two controls the user sees on portables map to the two pmset per-source values [INFERENCE: mapping direction; the strings themselves are observed verbatim].
- Read: parse the right section of `pmset -g custom`; decide which is active with `IOPSGetProvidingPowerSourceType()` (or `pmset -g batt`, observed: `Now drawing from 'AC Power'`).
- Write: `pmset -b displaysleep N` / `pmset -c displaysleep N` (root). On a desktop (no battery) only the AC value exists.

## 3. Sandbox, entitlements, TCC (Debug-signed, App Sandbox ON)

Live-tested with a real sandboxed binary: a Swift CLI embedded in an ad-hoc-signed `.app` bundle carrying only `com.apple.security.app-sandbox = true`, spawning `/usr/bin/pmset` via `Process`.

- **Read (`pmset -g`): works under App Sandbox.** Observed: exit 0, full settings output. Spawning system binaries under `/usr/bin` is permitted by the App Sandbox profile; the child inherits the sandbox; no entitlement or TCC prompt involved for pmset.
- **Write (`pmset -a displaysleep 60`): fails at pmset's own root check** under the sandbox (`'pmset' must be run as root...`, exit 1) — the sandbox does not add a separate denial; root is the blocker. The setting was unchanged after the probe (still 60; write was a same-value no-op and never succeeded).
- **No TCC involvement for pmset.** TCC only enters for the alternatives: Apple Events/UI scripting (Automation/Accessibility) and admin-auth prompts.
- **Debug signing:** Debug builds are typically ad-hoc or dev-cert signed; neither grants privilege. Root elevation cannot be obtained by any entitlement a Debug app can hold — this is a hard wall, not a signing-config issue.
- **Gotcha observed:** a sandboxed ad-hoc binary run *outside* a proper bundle (bare binary in /tmp) died at launch with SIGTRAP (exit 133) — sandbox container/identifier resolution requires a stable signed bundle (CFBundleIdentifier). Keep the app in its normal signed `.app` and this never applies.
- Entitlement routes for elevated writes, if ever needed:
  - `com.apple.security.temporary-exception.apple-events` — lets a sandboxed app send Apple events (App Store-ineligible; acceptable in Debug). Still needs the user to grant Automation TCC for the target app, and admin auth still prompts.
  - SMAppService privileged helper (see §5) — sandbox-compatible by design; no TCC.

## 4. Observable failure modes

1. Non-root `pmset` write: `'pmset' must be run as root...` on stdout, exit code 1, nothing changes. (Observed twice: plain shell and inside App Sandbox.)
2. Sandboxed ad-hoc binary not in a signed bundle: crash at launch, SIGTRAP / exit 133. (Observed.)
3. `defaults read com.apple.EnergySaver.portable.BatteryPower`: `Domain com.apple.EnergySaver.portable.BatteryPower does not exist` on desktops; the domain is daemon-private and not a stable read source. (Observed.)
4. UI scripting without TCC grants: `osascript` targeting System Events → error `-1719` "not allowed assistive access". (Observed.) Expect a parallel Automation ("Apple Events") prompt when sending events to System Settings.
5. Assertions override the timer: `man pmset` — "processes may dynamically override these power management settings by using I/O Kit power assertions." If any process holds `PreventUserIdleDisplaySleep`, the display won't turn off at the configured interval even after a successful write (`pmset -g assertions` lists holders). NeverSleep itself could later be the cause of this if it adds an assertion path — worth a UI note.
6. `pmset -g` output is CLI text, not an API: keys are stable English in practice but undocumented; a future OS could reword/relocate. Parse per-source sections from `-g custom` and treat unknowns as "unavailable", never crash.
7. Writing via `defaults` to powerd-owned domains is silently ignored (daemon caches) — a tempting dead end.
8. Deep link can silently fail to navigate if System Settings is mid-launch (observed once: app launched, no pane window; re-issuing the `open` after launch landed on the pane). Retry-once is a sufficient mitigation.

## 5. No supported write API — least-bad alternatives (ranked for NeverSleep v1)

There is **no supported, non-root, public write API** for the display-off interval on macOS 26 (confirmed via SDK headers, Apple docs search, live pmset behavior, and inspection of the System Settings machinery). Ranked options:

1. **Deep link to the Lock Screen pane (v1, zero entitlements, sandbox-friendly).** Verified end-to-end: `open "x-apple.systempreferences:com.apple.Lock-Screen-Settings.extension"` lands System Settings on the Lock Screen pane (window titled 锁定屏幕; screenshot captured). Bundle id `com.apple.Lock-Screen-Settings.extension` read from `/System/Library/ExtensionKit/Extensions/LockScreen.appex/Contents/Info.plist`. The app reads the current value (§1) and hands the user off to the dropdown — user performs the write. Weakest UX but the only path with no entitlement/TCC/root surface.
2. **AppleScript admin auth (least-bad *in-app* write, Debug-friendly).** `osascript -e 'do shell script "pmset -a displaysleep N" with administrator privileges'` runs the supported `pmset` CLI elevated. Requires: (a) App Sandbox **off** in the Debug configuration, or the `com.apple.security.temporary-exception.apple-events` entitlement; (b) the user's admin password on every write (SecurityAgent prompt). Works today, uses only supported components (pmset + AuthorizationServices), but is per-write interactive and blocks on the password dialog.
3. **SMAppService privileged helper (production-grade).** `SMAppService.daemon(plistName:)` (macOS 13+; https://developer.apple.com/documentation/servicemanagement/smappservice/daemon(plistname:)) installs a bundled LaunchDaemon that runs `pmset` as root; user approves once in System Settings → Login Items; sandbox-compatible. This is the architecture utilities use. Cost: helper target, real (non-ad-hoc) signing for reliable registration, approval UX. Overkill for a Debug-only v1, but the correct end state if the product must write in-app.
4. **Private API (explicitly labeled; not recommended).** `IOPMConnectionCreate`/`IOPMSetSleepSettings`-style calls or the pane's `setMinutesUntilDisplaySleeps:for:` via private frameworks — **private**, absent from the SDK (verified), sandbox likely denies the mach service to third-party apps, breaks without notice across OS releases. Do not build v1 on this.
5. **Assertion-based alternative (supported, no root, sandbox-safe).** The app cannot *set* the interval, but it can *prevent* display sleep at runtime with `IOPMAssertionCreateWithName(kIOPMAssertPreventUserIdleDisplaySleep, ...)` — the same mechanism as `caffeinate -d` (`man caffeinate`: "-d Create an assertion to prevent the display from sleeping"). Docs: https://developer.apple.com/documentation/iokit/1557134-iopmassertioncreatewithname and https://developer.apple.com/documentation/iokit/kiopmassertiontypepreventuseridledisplaysleep. Good for a "keep display on while I'm working" mode; does not persist a setting and stops at app quit.

## Implications for NeverSleep

- Read the interval from `pmset -g custom` (per-source `displaysleep`, minutes; `0` = never) via `Process`; use IOPowerSources (`IOPSGetProvidingPowerSourceType`) to know battery vs AC. Both verified sandbox-safe; no entitlements.
- v1 local Debug should **not attempt a programmatic write**: there is no supported non-root API. Ship read + deep link (`x-apple.systempreferences:com.apple.Lock-Screen-Settings.extension`); treat the Lock Screen dropdown as the write surface, with the app showing current values and a "change it for you" shortcut.
- If in-app writing is a hard product requirement even in Debug: disable App Sandbox in the Debug configuration (Debug entitlements only) and use AppleScript `do shell script "pmset -b|-c displaysleep N" with administrator privileges`, accepting a password prompt per write; document the Automation TCC grant.
- Plan the SMAppService privileged helper only if/when writing must be silent and persistent across a signed release — it is the only clean supported architecture.
- Do not touch `com.apple.EnergySaver.portable.*` cfprefs or any `IOPMConnection` symbol: one is daemon-private storage, the other is private API with no SDK header (both verified on macOS 26.5.2).
- Remember assertions can defeat the configured timer while the app (or any process) holds `PreventUserIdleDisplaySleep`; if NeverSleep later adds a "keep awake" mode, reflect that state in the UI so the interval appears to "not work".
- All findings verified on this machine (macOS 26.5.2, build 25F84); nothing user-visible was changed (only same-value no-op writes that failed before applying; user power settings unchanged).
