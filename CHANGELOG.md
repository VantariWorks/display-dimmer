# Changelog

This changelog covers notable Display Dimmer updates. Older entries are less
detailed than newer release notes, but are kept for historical context.

Some maintenance and packaging-only releases are omitted.

## v2.2.3 (June 29, 2026)
This update focuses on local automation, Settings polish, and reliability improvements.

### New
- Local automation and command-line support for Display Dimmer Pro.
- Control display brightness and contrast from scripts through the running Display Dimmer app.
- Optional JSON output and state watching for PowerShell, AutoHotkey, Task Scheduler, Stream Deck, Arduino, and other local automation workflows.
- More hotkey actions for display control.

### Improved
- Better handling for monitor reconnects, display changes, and DDC/CI fallback.
- Improved Settings refresh behavior around display changes and DDC/CI state changes.
- Added a hint when Windows or another app appears to reset screen brightness.
- Reliability fixes for linked display groups, schedules, app rules, and hotkeys.

## v2.2.2 (May 25, 2026)
- Reduced misleading DDC/CI prompts for built-in displays or displays that do not detect DDC/CI.
- Polished drag reordering for displays, schedules, hotkeys, and app rules.
- Bug fixes and reliability improvements.

## v2.2.1 (May 23, 2026)
- Stability fixes for monitor reconnects, HDR/display changes, and DDC/CI fallback.
- Clearer fallback behavior when DDC/CI is unavailable or a monitor is slow to respond.

## v2.2.0 (May 19, 2026)

Display Dimmer 2.2 is a major hotkey and reliability update. It adds
customizable global hotkeys, support for physical brightness keys, a redesigned,
resizable Settings window, improved monitor-control reliability, and linked
display groups for larger multi-monitor setups.

### New

- Added a global hotkey editor for brightness, contrast, reset levels, display
  enable/disable, and automation actions.
- Added default global brightness hotkeys:
  - `Ctrl + Alt + Page Up` for brightness up.
  - `Ctrl + Alt + Page Down` for brightness down.
- Added hotkey targeting for individual displays, All Displays, and linked
  display groups.
- Added support for physical brightness keys on compatible keyboards and devices.
- Added a redesigned, resizable Settings window with side navigation and
  remembered window size.
- Added linked display groups for larger multi-monitor setups, with support in
  the main controls, schedules, app rules, and hotkeys.
- Added guide links for DDC/CI, schedules, app rules, and hotkeys.
- Added a What's New popup in About.

### Improved

- Updated Display Dimmer to .NET 8 for a more modern Windows build.
- Improved hardware brightness reliability across startup, sleep/resume, HDR
  changes, reconnects, and display changes.
- Improved software fallback, retry, and auto-disable behavior when DDC/CI
  hardware control is unavailable or unreliable.
- Improved DDC/CI disabled notifications with clearer explanations.
- Improved display matching and recovery when monitors are reconnected or moved
  to another port, without restoring hardware-control preferences when the match
  is uncertain.
- Improved Settings organization and control layout for multi-monitor and
  automation-heavy setups.
- Improved schedule and app-rule status text and restore behavior when
  automation is interrupted, disabled, or handed off between rules.
- Improved startup behavior after an unclean shutdown or crash so active
  automation can reapply software dimming when needed.
- Improved shutdown and exit cleanup behavior for hardware-controlled and
  software-dimmed displays.

### Fixed

- Fixed a startup recovery case where automation-owned software dimming could be
  reset.
- Fixed app-rule browse validation so selecting a non-`.exe` file behaves like
  drag-and-drop validation.
- Fixed rating prompt behavior so a shown prompt is marked as seen immediately
  and is cleaned up when Display Dimmer exits.

## v2.1.25 (April 20, 2026)

- Added fullscreen-aware app rules, including a Pro option to apply fullscreen
  rules only to the display running the fullscreen app.
- Added a Settings option for All Displays brightness behavior: relative mode
  to preserve per-display differences, or absolute mode to set every display to
  the same level.
- Improved All Displays slider behavior at 0%, 100%, and in mixed-monitor
  setups.
- Improved schedule and app-rule status text, selected-scope persistence,
  Apply/resume behavior, and restore behavior after interruption.
- Improved gamma fallback stability at low brightness, high contrast, and for
  automation-owned displays.
- Improved DDC/CI write stability and reduced redundant monitor brightness
  writes.
- Improved manual contrast persistence after mouse and keyboard adjustments.
- Added startup render-crash recovery with software-render fallback.
- Fixed a rare crash that could occur on some devices when clicking a URL in
  the About tab.
- Improved diagnostics and hang reporting performance.
- General stability and performance improvements.

## v2.1.24 (April 5, 2026)

- Improved update notification behavior so update prompts can be deferred and
  shown from the main window more reliably.
- Refined Pro upsell copy and Pro theme messaging.
- General startup and prompt reliability improvements.

## v2.1.23 (April 1, 2026)

- Fixed an issue where Display Dimmer could still show its main window at
  startup when Start with Windows was enabled and Launch behavior was set to
  Start in tray.
- Fixed a scheduling issue that could affect brightness rules after changing
  display order.
- Improved Settings window responsiveness and scrolling.
- Improved schedule/app-rule Apply behavior and status updates.
- Improved startup, update notification, and autostart handling.
- Miscellaneous stability and reliability improvements.

## v2.1.22 (March 11, 2026)

- Fixed a rare startup stability issue.
- Improved update notification and startup handling.
- Improved rate-prompt eligibility checks.
- General reliability improvements.

## v2.1.21 (March 4, 2026)

- On new PCs or fresh installs, Display Dimmer can now detect an existing Pro
  purchase on startup without requiring users to open the purchase screen.
- Improved Pro restore and Pro upsell behavior.
- Improved gamma/DDC startup handling.
- Improved schedule and Settings behavior around Pro state changes.

## v2.1.20 (March 1, 2026)

- Fixed a bug where gamma dimming applied by schedules or app rules could
  persist after exit during multi-monitor rule activity.
- Fixed drag-to-scroll on schedule and app-rule cards.
- Added a rating prompt shown sparingly based on usage, crashes, and DDC
  reliability.
- Added a Pro purchase confirmation window to clearly show when Pro has been
  unlocked.
- Improved brightness control reliability across display, DDC/CI, gamma,
  automation, and app lifecycle paths.
- Improved diagnostics and hang reporting reliability.

## v2.1.19 (February 8, 2026)

- Refined slider shadow effects to improve performance.
- Improved Pro session handling.
- Improved schedule/app-rule handoff and slider state behavior.
- Stability improvements and bug fixes.

## v2.1.18 (February 4, 2026)

- Improved the All Displays slider so multiple monitors adjust more
  consistently.
- Added update prompts.
- Improved startup reapply behavior so active schedules or app rules can own
  startup brightness instead of being overwritten by saved manual levels.
- Improved update notification storage so the same Store version is not shown
  repeatedly.
- Improved hang-report false-positive suppression around startup and app
  lifecycle events.
- Improved main-window slider reliability.
- Bug fixes and improvements.

## v2.1.17 (January 30, 2026)

- Fixed DDC/CI brightness scaling on some monitors.
- Improved DDC/CI write coalescing and failure handling.
- Improved gamma dimming reliability on slower systems.
- Added new Pro themes and UI improvements.
- Added Pro upsell UI refinements.
- Improved tray, startup, and theme synchronization.
- Improved scrollbar/theme polish.

## v2.1.16 (January 26, 2026)

- Improved tray menu behavior.
- Added gamma guard support to help protect against Windows or GPU gamma resets.
- Improved DDC/CI brightness VCP probing and caching for monitors that expose
  brightness through different VCP codes.
- Improved app-rule Settings behavior.

## v2.1.15 (January 22, 2026)

- Fixed false crash reports in diagnostics.
- Improved crash/hang classification and diagnostics suppression.

## v2.1.14 (January 21, 2026)

- Added an option to reapply gamma if Windows overrides brightness.
- Improved All Displays sliders so multiple screens adjust relative to their
  current levels.
- Improved hotplug safety when Windows temporarily reports zero displays.
- Improved gamma reset/reassert behavior for gamma-fallback displays.

## v2.1.13 (January 17, 2026)

- Follow-up to v2.1.12 with reliability and packaging improvements.
- Improved gamma reset behavior after reset-level actions.
- Improved display refresh handling during hotplug storms.
- Improved All Displays selection and slider state behavior.

## v2.1.12 (January 15, 2026)

- Released the Display Dimmer Pro add-on as an optional upgrade with unlimited
  rules, extra themes, and advanced controls.
- Fixed cases where per-app brightness might not fully restore on app exit.
- Improved exit handling.
- Improved display hotplug support.

## v2.1.11 (January 12, 2026)

- Added smooth gamma-based transitions.
- Improved slider responsiveness so fast drags do not queue stale monitor
  brightness writes.
- Improved DDC/CI compatibility and general stability.
- Improved display identity persistence so hardware-control settings are less
  likely to follow a fragile `DISPLAY1` / `DISPLAY2` port alias.
- Improved hang diagnostics with more complete crash/hang report collection and
  system context.
- Added Store purchase support for Pro UI.

## v2.1.10 (January 5, 2026)

- Added drag-and-drop reordering for display cards, schedules, and per-app
  cards.
- Added basic keyboard shortcuts.
- Improved hotplug handling.
- Fixed Start in tray behavior.
- Added optional crash and hang reporting.

## v2.1.9 (December 29, 2025)

- Improved startup restore behavior after a previous crash or unclean exit.
- Improved DDC notification de-duplication across display episodes.
- Improved Reapply on launch state handling.
- Improved hang detection around sleep, resume, lock, unlock, and idle periods
  to reduce false positives.
- Improved diagnostics capture for hangs and startup recovery.

## v2.1.8 (December 25, 2025)

- Added crash and hang diagnostics infrastructure.
- Added pending diagnostics report handling.
- Added drag/reorder support for Settings cards.
- Improved DDC/CI startup retry behavior during startup grace periods.
- Improved UI responsiveness by keeping DDC/CI work away from the main UI path.
- Improved hotplug and DDC handle invalidation behavior.
- Improved tray menu styling and app icon resources.

## v2.1.7 (December 21, 2025)

- Improved the Settings UI for schedules and per-app brightness rules.
- Added Pro coming-soon messaging around advanced automation features.
- Improved DDC/CI responsiveness by reducing repeated monitor setup and
  capability work.
- Improved packaged and unpackaged Start with Windows handling.
- Improved Settings controls, button styling, and theme-aware UI resources.

## v2.1.4 (December 7, 2025)

- Maintenance update in the early v2.1 automation line.
- Improved packaging and release preparation.

## v2.1.3 (December 6, 2025)

- Improved the automation Settings UI leading into the v2.1 release line.
- Added early Pro-related messaging for upcoming advanced features.
- Improved theme resource coverage and polished Settings controls.
- Improved startup and DDC/CI behavior around saved settings reapply.

## v2.1.0 (December 3, 2025)

Display Dimmer 2.1 is a major automation update.

- Added scheduled brightness rules so displays can dim or brighten
  automatically by time of day.
- Added per-app brightness rules so apps can use their own brightness levels.
- Added the All Displays control to adjust every monitor at once.
- Added Settings pages and persistence for schedule and per-app rule lists.
- Added background automation so schedules and app rules can apply brightness
  while Display Dimmer runs in the tray.
- Added initial rule enable/disable behavior and automation status handling.
- Added support for restoring brightness when an automation rule stops.
- Improved startup, tray, and reapply behavior so saved brightness and
  automation could work together.
- Improved monitor-control stability while adding automation on top of DDC/CI
  and gamma fallback.

## v2.0.9 (November 21, 2025)

- Improved monitor naming so connected displays could be shown with clearer
  labels.
- Improved DDC/CI display identification around monitor names.
- Improved UI polish and packaging around the late v2.0 line.

## v2.0.8 (November 17, 2025)

- Maintenance update in the v2.0 line.
- Improved packaging and release stability.

## v2.0.7 (November 16, 2025)

- Improved Settings and app UI styling.
- Added more polished theme resources and control styling.
- Added Pro preview UI and preview-expiry handling.
- Improved launch/startup behavior and Settings tab memory.
- Improved tray notifications and hidden-window behavior.

## v2.0.4 (November 14, 2025)

- Improved DDC/CI error messaging for monitor-control failures.
- Prepared early Store and Pro support.
- Improved packaged-app behavior and compatibility work.

## v2.0.2 (November 13, 2025)

- Maintenance update in the v2.0 line.
- Improved packaged-app compatibility.

## v2.0.1 (November 12, 2025)

- Maintenance update around the early v2 UI and packaged app flow.
- Improved window launch behavior and Settings tab memory.

## v2.0.0 (November 12, 2025)

Display Dimmer 2.0 is a major app-shell, packaging, and UI polish update.

- Began the v2 packaged app line.
- Refreshed the main window and Settings UI with more polished sliders,
  shadows, scrollbars, and theme-aware resources.
- Added click-to-drag slider track behavior.
- Expanded the Settings experience for display settings, startup/tray
  behavior, launch behavior, themes, opacity, and monitor-control options.
- Moved About/help information into the broader app/settings experience.
- Improved startup behavior for saved display levels and reapply-on-launch.
- Improved tray behavior, remembered window position, and remembered selected
  display state.
- Improved DDC/CI startup handling by warming capability checks and avoiding
  unnecessary startup hardware writes.
- Improved saved display matching with identity, device, friendly-name, and
  label fallback paths.
- Improved settings persistence with safer JSON writes and backup recovery.
- Continued improving DDC/CI and gamma fallback handoff behavior.

## v1.0.2 (November 6, 2025)

- Maintenance update for the initial release line.
- Improved early packaging and release stability.

## v1.0.1 (November 5, 2025)

- Added light and dark theme resources.
- Added system-theme detection.
- Added window opacity settings.
- Improved Settings buttons and Settings window polish.
- Improved Start with Windows and Start in tray behavior.
- Improved startup reapply handling for saved brightness levels.
- Improved DDC/CI toggle behavior and fallback wording.

## v1.0.0 (November 2, 2025)

- Initial Display Dimmer release.
- Added per-display brightness and contrast controls.
- Added DDC/CI hardware brightness support where available.
- Added GPU gamma fallback for displays without working DDC/CI brightness.
- Added display selection for connected monitors.
- Added tray icon support.
- Added basic settings persistence.
