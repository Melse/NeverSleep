# Lock Screen "turn display off when inactive" — display-off options on macOS 26

Research ticket: Melse/NeverSleep#2 (wayfinder, `research/lock-screen-options`).
Researched on this machine (primary sources): `sw_vers` → macOS 26.5.2 (Build 25F84), Apple M4 Mac mini (Mac16,10, no battery/UPS). Written 2026-08-03.

---

## Q1. One control, or split (battery vs plugged in)?

**Split by power source.** The Lock Screen pane defines a *separate display-off option list and selection per power source*, and only renders the rows that apply to the machine:

- The pane binary (`/System/Library/ExtensionKit/Extensions/LockScreen.appex`) contains per-source Swift ivars `_displayOffDelayOptionsOnAC`, `_displayOffDelayOptionsOnBattery`, `_displayOffDelayOptionsOnUPS` plus selected-value ivars `_selectedDisplayOffDelayOnAC/Battery/UPS`, a `defaultDisplayOffDelayOptions` static, and machine-capability flags `_hasBattery`, `_hasUPS` (symbol table via `nm`, and `strings`).
- Three distinct labels exist in the pane's localization table (see Q3): battery, power adapter, UPS. Apple's macOS Tahoe 26 docs say Mac notebooks show **two** rows — "Turn display off on battery when inactive" and "Turn display off on power adapter when inactive" — while desktops show a single "Turn display off when inactive".
  - https://support.apple.com/guide/mac-help/change-lock-screen-settings-on-mac-mh11784/mac (version selector: macOS Tahoe 26)
  - https://support.apple.com/zh-cn/guide/mac-help/mh11784/mac (same, zh-Hans)
- On this Mac mini (AC-only, no battery, no UPS): exactly **one** row ("Turn display off when inactive"); the battery/UPS rows are suppressed. Confirmed by the `_hasBattery`/`_hasUPS` flags in the binary plus `system_profiler SPPowerDataType` (only "AC Power" present) and `pmset -g custom` (only "AC Power:" section).

The control is a **pop-up menu (Picker)**, not a slider: the pane's accessibility string "Picker label." and Apple's doc wording "Click the pop-up menu next to … then choose an option" (support.apple.com, Set sleep and wake settings, Tahoe 26: https://support.apple.com/guide/mac-help/set-sleep-and-wake-settings-mchle41a6ccd/mac, zh: https://support.apple.com/zh-cn/guide/mac-help/mchle41a6ccd/mac).

## Q2. Discrete option list the UI offers

Extracted from the LockScreen.appex binary (`__TEXT` data; same blob duplicated in `/System/Library/ExtensionKit/Extensions/Wallpaper.appex`, which owns the Screen Saver "Start after" popup). Three numeric arrays were located:

| Popup | Values (raw, little-endian int64 in binary) | Reading | Unit |
|---|---|---|---|
| Turn display off … when inactive | `[1, 2, 3, 5, 10, 20, 30, 60, 90, 120, 150, 180]` | 1, 2, 3, 5, 10, 20, 30, 60, 90, 120, 150, 180 minutes (1 min → 3 h), plus **Never** | minutes |
| Start Screen Saver when inactive | `[12, 24, 60, 120, 180, 300, 600, 1200, 1800, 3600, 5400, 7200, 9000, 10800]` | 12 s, 24 s, 1, 2, 3, 5, 10, 20, 30 min, 1, 1.5, 2, 2.5, 3 h, plus **Never** | seconds |
| Require password after screen saver begins… | `[5, 60, 300, 900, 3600, 14400, 28800]` | 5 s, 1, 5, 15 min, 1, 4, 8 h, plus **Immediately** (0) | seconds |

Why the assignments hold ([INFERENCE] where interpretive, evidence below):

- **Display-off values are minutes**: the pane's setter is `setMinutesUntilDisplaySleeps:for:` and reader `displaySleepsFor:` (binary strings); `man pmset`: "displaysleep - display sleep timer … (value in minutes, or 0 to disable)"; the live value on this machine is **60**, which belongs to the minutes array (`pmset -g` → `displaysleep 60`; `/Library/Preferences/com.apple.PowerManagement.plist` → "AC Power" → "Display Sleep Timer" = 60; `system_profiler SPPowerDataType` → AC Power → "Display Sleep Timer (Minutes): 60").
- **Screen-saver values are seconds**: the screensaver idle time is stored in seconds — `/System/Library/Frameworks/ScreenSaver.framework/Versions/A/Resources/EngineDefaults.plist` → `idleTime = 1200` (20 min), which is present in the seconds array; the seconds array is the only one of the three duplicated in Wallpaper.appex, which configures only the screen saver start delay.
- **Password values**: `[5, 60, 300, 900, 3600, 14400, 28800]` s matches the well-known macOS set (5 s, 1 m, 5 m, 15 m, 1 h, 4 h, 8 h); the pane adds a zero-interval row — binary string "Picker option. Represents zero time interval." (i.e. "Immediately") — alongside "Picker option. Represents infinite time interval." ("Never") and "Picker option. Parameter is localized time interval string." (normal rows).
- **Never = 0 minutes** for display-off (pmset "0 to disable"; the pane's "Never" label is in the localization table and the warning "Never letting your display turn off may shorten its lifespan and increase energy usage." appears when it is selected).

Not verified ([INFERENCE]): the exact user-visible row labels ("1 minute", "1.5 hours", …) are generated at runtime from the numbers — no localized duration strings exist in the pane's `.loctable` — so only the numeric values above are extractable. The 12 s / 24 s screen-saver entries are unusual but are present verbatim in both extensions. UI-level screenshot verification was not possible (this session has no WindowServer; `screencapture` fails with "could not create image from display").

## Q3. Exact EN and zh-Hans labels (from LockScreen.appex `Localizable.loctable`)

EN (`en`):
- "Turn display off when inactive" (desktop single control)
- "Turn display off on battery when inactive"
- "Turn display off on power adapter when inactive"
- "Turn display off on UPS when inactive"
- "Never"
- "Start Screen Saver when inactive"
- "Require password after screen saver begins or display is turned off"
- "Display will sleep before screen saver starts." (warning when display-off < screen-saver delay)
- "Never letting your display turn off may shorten its lifespan and increase energy usage." (warning for Never)
- "Energy usage may be higher when this Mac is inactive for longer periods of time before the display turns off."
- "To use less energy, click Reset."

zh-Hans (`zh_CN`):
- 不活跃时关闭显示器 ("Turn display off when inactive")
- 使用电池供电且不活跃时关闭显示器
- 使用电源适配器供电且不活跃时关闭显示器
- 使用UPS供电且不活跃时关闭显示器
- 永不 ("Never")
- 不活跃时启动屏幕保护程序 ("Start Screen Saver when inactive")
- 屏幕保护程序启动或显示器关闭后需要密码
- 显示器将在屏幕保护程序启动前进入睡眠状态。
- 显示器永不关闭可能会缩短其寿命并增加电量使用。

zh-Hans match Apple's Tahoe 26 docs verbatim (support.apple.com/zh-cn/guide/mac-help/mh11784/mac). The pane's display name is "锁定屏幕" / "Lock Screen" (`InfoPlist.loctable`, `CFBundleDisplayName`).

## Q4. Preference domains / keys

Grounded in the pane binary (strings), system plists on this machine, and man pages:

- **Display-off delay**: written by the pane as key **"Display Sleep Timer"** (minutes) into the per-source domains referenced in the binary:
  - `com.apple.EnergySaver.desktop.ACPower` (desktop, AC)
  - `com.apple.EnergySaver.portable.ACPower` (portable, AC)
  - `com.apple.EnergySaver.portable.BatteryPower` (portable, battery)
  - Surfaces as `pmset displaysleep` (minutes; 0 = never) and is persisted at the system level in `/Library/Preferences/com.apple.PowerManagement.plist` under `AC Power` → `Display Sleep Timer` (verified: 60 on this machine). `system_profiler SPPowerDataType` mirrors it ("Display Sleep Timer (Minutes)").
- **Screen saver start delay**: `com.apple.screensaver` → **`idleTime`** (seconds; system default 1200 per ScreenSaver.framework `EngineDefaults.plist`). Currently unset in the user domain on this machine (`defaults read com.apple.screensaver` → only `tokenRemovalAction`).
- **Password delay**: `com.apple.screensaver` → **`askForPasswordDelay`** (seconds; 0 = immediately) — key name present in the pane binary next to the `com.apple.screensaver` domain string.
- Other domains referenced by the pane: `com.apple.loginwindow`, `com.apple.preference.security` (key `dontAllowLockMessageUI`).
- Programmatic surface: `pmset -g` / `pmset -g custom` (current: `displaysleep 60`); write via `pmset displaysleep <minutes>` requires root (man pmset).

## Method / evidence notes

- Binary analysis: `strings`, `nm`, `otool -ov/-l` on `/System/Library/ExtensionKit/Extensions/LockScreen.appex/Contents/MacOS/LockScreen` (bundle id `com.apple.Lock-Screen-Settings.extension`) and `/System/Library/ExtensionKit/Extensions/Wallpaper.appex`. Option arrays located as contiguous little-endian int64 runs in `__TEXT`; password array cross-validated against the known macOS set.
- Localization: `plutil -convert json` on `LockScreen.appex/Contents/Resources/Localizable.loctable` (locale keys `en`, `zh_CN`, …).
- Live state: `sw_vers`; `system_profiler SPHardwareDataType` / `SPPowerDataType`; `pmset -g` / `pmset -g custom`; `defaults read` on `com.apple.screensaver`, `com.apple.powermanagement`, `com.apple.EnergySaver.*` (user domains absent — system plist is the source of truth); `/Library/Preferences/com.apple.PowerManagement.plist`.
- Apple docs read directly: change-lock-screen-settings (EN/zh-CN, Tahoe 26), set-sleep-and-wake-settings (EN/zh-CN, Tahoe 26).
- UI screenshot could not be captured (headless session, no WindowServer); UI claims above rest on the binary localization/accessibility strings and Apple docs.

## Implications for NeverSleep

- The display-off interval is **per power source**, not one global value: on portables there are two (battery / adapter) independent timers, on desktops one. NeverSleep's menu-bar value must read/write the right source — decide whether it edits "all sources" (e.g. via `pmset displaysleep` for AC and battery) or mirrors the currently active source.
- Discrete values are minute-based (1–180 min plus Never=0); NeverSleep should treat the setting as a minute integer, with 0 = never, and snap/clamp to this domain if it offers its own UI.
- Grounded storage contract: `pmset displaysleep <min>` (root) and/or the `com.apple.EnergySaver.*` "Display Sleep Timer" keys; screensaver timing is a separate setting (`com.apple.screensaver idleTime`, seconds) — do not conflate them.
- macOS 26 UI labels to reuse for parity: "Turn display off when inactive" / 不活跃时关闭显示器 (with per-source variants on portables), "Never" / 永不.
- Watch the pane's power-source rows: on this machine only AC exists; a NeverSleep feature that assumes battery/adapter pairs would be wrong for desktops (and for UPS-equipped machines, a third row exists).
