# Examples

These examples show how to use `DisplayDimmer.Cli.exe` to control Display Dimmer from scripts, scheduled tasks, C# apps, and sensor projects.

The examples assume Display Dimmer is installed from the Microsoft Store and already running in the same Windows user session as the script or tool.

## Requirements

- Display Dimmer installed from the Microsoft Store.
- Display Dimmer running.
- Display Dimmer Pro.
- Local automation enabled in Display Dimmer:
  Settings > General > Advanced > Local automation > Manage...
- `DisplayDimmer.Cli.exe` is available from PowerShell.

Check that the CLI is available:

```powershell
DisplayDimmer.Cli.exe --list-displays
```

If PowerShell cannot find the command, check Windows app execution aliases or reinstall/update Display Dimmer from the Microsoft Store.

## Choose A Target

Most examples need a display target.

Run:

```powershell
DisplayDimmer.Cli.exe --list-displays
```

Copy the `targetId` for the physical display or linked display group you want to control.

Recommended target forms:

- `primary` for the current Windows primary display.
- `all` for every controllable display.
- `dd_...` for physical displays or linked display groups in saved scripts and long-term automation.
- `display_1`, `display_2`, etc. only for quick session tests.

If a display only has a `display_N` target, rerun `--list-displays` after docking, hotplug, GPU driver changes, or display layout changes. Linked group target IDs are stable `dd_...` IDs when the group exists.

## Available Examples

- [Automation recipes](automation-recipes/)
  Shows practical command patterns for manual overrides, cooperative sensors, handoff updates, linked groups, and scheduled scripts.

- [C# client](csharp-client/)
  Shows how a C# app can call `DisplayDimmer.Cli.exe`, parse JSON, choose a display, set brightness, and read state back.

- [Task Scheduler](task-scheduler/)
  Shows how to create a Windows Task Scheduler task that calls `DisplayDimmer.Cli.exe` at a chosen time.

- [AutoHotkey shortcuts](autohotkey/)
  Shows how to bind `DisplayDimmer.Cli.exe` commands to Ctrl+Alt keyboard shortcuts.

- [Stream Deck and macro buttons](stream-deck/)
  Shows Program/Arguments recipes for Stream Deck and similar macro tools.

- [Arduino light sensor](arduino-light-sensor/)
  Shows a cooperative sensor workflow where a Windows bridge reads serial data, stands by for schedules/app rules, and keeps a handoff brightness value fresh.

- [Arduino motion sensor](arduino-motion-sensor/)
  Shows a plain motion/presence workflow where idle dimming acts like a manual override by default.

- [Arduino motion sensor + Nokia LCD](arduino-motion-sensor-lcd/)
  Shows the same motion workflow with a Nokia 5110 / PCD8544 LCD status display.

## Script Guidance

Use JSON output when another tool needs to inspect success, errors, or partial success:

```powershell
DisplayDimmer.Cli.exe --set-brightness 40 --target primary --json --pretty
```

Use `--source cli` for scripts that should act like manual overrides and interrupt schedules/app rules. That is usually the right choice for buttons, hotkeys, task actions, and no-motion dimming.

If a script, hotkey, macro, or sensor needs to dim lower than normal brightness `0`, use the [extra-dark dimming recipe](automation-recipes/README.md#extra-dark-dimming) instead of raw VCP commands.

Use a named source for cooperative sensor bridges that should stand down while Display Dimmer automation owns the display:

```powershell
DisplayDimmer.Cli.exe --set-brightness 45 --target primary --source cli
DisplayDimmer.Cli.exe --update-external-brightness 45 --target primary --source desk-light-sensor
```

For durable scheduled scripts, prefer a stable `dd_...` target ID. For quick shortcuts that should follow the current Windows primary monitor, use `primary`.

PowerShell bridge scripts use one-dash parameters such as `-Port COM7` and `-Target all`. `DisplayDimmer.Cli.exe` commands use two-dash options such as `--target all`. In the Arduino examples, `COM7` is only an example; replace it with the port shown in Arduino IDE under Tools > Port.

## Troubleshooting

- `appUnavailable`: Display Dimmer is not running, Local automation is off, or the script is running as a different Windows user.
- `targetNotFound`: rerun `DisplayDimmer.Cli.exe --list-displays` and use the current `targetId`.
- `partial=true` with `errorCode=partialSuccess`: one or more targets failed; use `--json --pretty` to see per-display results.
- Task Scheduler issues: use "Run only when user is logged on" and run the task as the same Windows user as Display Dimmer.
