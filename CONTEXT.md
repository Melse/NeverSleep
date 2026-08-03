# NeverSleep

A macOS menu-bar app for quickly changing how long the Mac waits while inactive before turning the display off.

## Language

**NeverSleep**:
The macOS menu-bar application in this repository.
_Avoid_: the tray app, the utility (when referring to this product by name)

**Menu bar icon**:
The status-item control NeverSleep shows in the system menu bar after launch (icon plus optional short value text).
_Avoid_: Tray icon, NSStatusItem (implementation), menubar button

**Popover**:
The panel attached to the menu bar icon that opens on click and holds the main controls.
_Avoid_: dropdown, popup window, main window

**Display-off interval**:
The idle time before macOS turns the display off — the value exposed by System Settings → Lock Screen → “Turn display off when inactive” / 「不活跃时关闭显示器」.
_Avoid_: lock screen timeout, screensaver timeout, sleep time (ambiguous with system sleep), lock delay

**Value label**:
The human-readable display-off interval text aligned with System Settings wording (for example “5 minutes” / 「5 分钟」, “Never” / 「永不」).
_Avoid_: caption, title, slider legend

**Launch at login**:
Whether NeverSleep starts automatically when the user logs in.
_Avoid_: login item (when speaking product language), SMAppService (implementation), open at login

**Quit**:
The control that terminates NeverSleep entirely and removes it from the menu bar.
_Avoid_: close, exit app (prefer Quit to match macOS)

## Relationships

- The **menu bar icon** shows a short **value label** for the current **display-off interval** and opens the **popover** on click.
- The **popover** can change the **display-off interval**, toggle **launch at login**, and **quit**.
