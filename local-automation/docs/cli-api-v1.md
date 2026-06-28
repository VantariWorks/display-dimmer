# Display Dimmer Command-Line/API v1 Reference

This document describes Display Dimmer's local command-line automation API.

The user-facing executable is the Display Dimmer command-line tool (`DisplayDimmer.Cli.exe`).

It lets local scripts and tools send commands to the already-running Display Dimmer app. The app owns display discovery, DDC/CI, software dimming, schedules, app rules, hotkeys, linked displays, diagnostics, and UI state. The CLI sends the request and exits.

For a shorter user-facing guide, see [Control Display Dimmer From Local Scripts](local-automation-api.md). For runnable samples, see [examples](../examples).

## Design Summary

- Local-only. No network listener.
- Current-user named pipe IPC with an explicit pipe ACL.
- `DisplayDimmer.Cli.exe` is the command to call from scripts.
- Local automation is a Display Dimmer Pro feature.
- The running Display Dimmer app owns monitor control.
- Commands are serialized inside the app.
- Watch streams observe cached app state and do not perform hardware polling.
- Brightness commands are live-only by default.
- `--save` is required to change saved brightness settings.
- `--set-brightness` with `--source cli`, or no `--source`, behaves like a manual live override.
- `--set-brightness` with any other `--source <name>` is cooperative external automation: it applies when no Display Dimmer automation owns the target, and stands down with a fresh handoff value when a schedule or app rule already owns it.

Security note: the local automation pipe is created with a current-user Windows ACL. Other Windows accounts are not granted access. Any process running in your Windows account can still send commands, so this is a local automation feature, not an authentication boundary between programs in the same account session.

For app privacy information, see [Display Dimmer privacy](https://displaydimmer.com/privacy).

## Entry Point

Use:

```powershell
DisplayDimmer.Cli.exe
```

For scripts that need an executable path, resolve the installed command:

```powershell
$cliPath = (Get-Command DisplayDimmer.Cli.exe -ErrorAction Stop).Source
```

Use the CLI from the same Display Dimmer version that is currently running. The CLI is only a client; the running app owns the Local automation server and response shape. Local automation is opt-in from Display Dimmer > Settings > General > Advanced > Local automation > Manage... and requires Display Dimmer Pro.

The WPF app can parse the same arguments internally, but the console companion is the right entry point for scripts because it provides normal stdout, stderr, and exit codes.

## Quick Start

Install or update Display Dimmer from the Microsoft Store, then start Display Dimmer from the Start menu or tray. Open Display Dimmer > Settings > General > Advanced > Local automation > Manage..., unlock Pro if prompted, and turn on **Local automation**.

Open PowerShell and set a `$cli` variable for the command:

```powershell
$cli = "DisplayDimmer.Cli.exe"
```

List displays:

```powershell
& $cli --list-displays
```

You can also copy display target IDs from the same Local automation window.

Set brightness for one display:

```powershell
& $cli --set-brightness 70 --target dd_your_stable_id
```

Set contrast for a display:

```powershell
& $cli --set-contrast 55 --target dd_your_stable_id
```

Get state:

```powershell
& $cli --get-state --target dd_your_stable_id --pretty
```

For scripts, add JSON:

```powershell
& $cli --set-brightness 70 --target dd_your_stable_id --json
```

## Commands

| Command | Purpose |
|---|---|
| `--help` | Print CLI help. |
| `--version` | Print Display Dimmer version text. |
| `--api-version` | Print the CLI/API protocol version. |
| `--list-displays` | List connected displays and copy-paste target IDs. |
| `--get-state` | Return display state and automation state. |
| `--set-brightness <0-100>` | Set absolute live Display Dimmer brightness through the normal app-owned brightness path. |
| `--adjust-brightness <-100..100>` | Adjust Display Dimmer brightness relative to current value through the normal app-owned brightness path. |
| `--set-contrast <0-100>` | Set live Display Dimmer contrast through the normal software/gamma contrast path. |
| `--adjust-contrast <-100..100>` | Adjust live Display Dimmer contrast through the normal software/gamma contrast path. |
| `--update-external-brightness <0-100>` | Refresh a standing-by external brightness value without applying it, so automation can hand off cleanly later. |
| `--set-ddc enabled\|disabled` | Change the saved DDC/CI preference for a display through Display Dimmer's normal DDC transition path. |
| `--list-vcp` | List Display Dimmer's known VCP controls and any monitor-advertised values. |
| `--get-vcp <code-or-name>` | Read an advanced DDC/CI VCP feature from a monitor. |
| `--set-vcp <code-or-name> <value>` | Write an allowed advanced DDC/CI VCP feature. High-impact writes require `--force`. |
| `--watch` | Stream local Display Dimmer state changes as JSON Lines. Requires `--json`. |

## Options

| Option | Applies to | Purpose |
|---|---|---|
| `--target <target>` | `--get-state`, brightness commands, contrast commands, DDC preference commands, VCP commands, `--update-external-brightness` | Select one display. Repeat `--target` to select more than one display. |
| `--json` | all commands that return structured data | Print compact JSON. |
| `--pretty` | all commands that return structured data | Print indented JSON. Implies `--json`. |
| `--save` | `--set-brightness`, `--adjust-brightness` | Save the brightness setting instead of live-only control. This is a settings write, not a cooperative sensor handoff. Not valid with contrast, VCP, DDC preference, or `--update-external-brightness` commands. |
| `--brightness-mode gamma\|software\|ddc` | `--set-brightness` | Force the normal Display Dimmer brightness route for this command. `gamma` and `software` disable DDC first; `ddc` enables DDC first. This is not a raw VCP write. |
| `--force` | `--set-vcp` | Allow a high-impact or raw VCP write after you have chosen a target that resolves to exactly one display. |
| `--verify` / `--no-verify` | `--set-vcp` | Override VCP readback verification. Verification is skipped for commands that can change input or power state. |
| `--source <name>` | `--set-brightness`, `--adjust-brightness`, `--update-external-brightness` | Controls automation handoff. Use `cli` or omit the option for manual override behavior. Use another name, such as `desk-light-sensor`, for cooperative external automation that stands down while schedules/app rules own the target. Use the same named source with `--update-external-brightness` while standing by. |
| `--timeout <ms>` | IPC commands | Override the Local automation timeout. |
| `--no-start` | reserved | Reserved for future app-start behavior. |

`--set-ddc` examples use `enabled` and `disabled`. For script convenience, the parser also accepts `enable`, `disable`, `on`, `off`, `true`, `false`, `1`, and `0`.

## Display IDs

Use `--list-displays` first:

```powershell
DisplayDimmer.Cli.exe --list-displays
```

Example:

```text
2 display(s):
  dd_your_stable_id | Display 1 (Odyssey G61SD) | session=display_1 | brightness=84 | contrast=50 | mode=software | automationInterrupted=false
    set: DisplayDimmer.Cli.exe --set-brightness 70 --target dd_your_stable_id
    json: DisplayDimmer.Cli.exe --set-brightness 70 --target dd_your_stable_id --json
  dd_your_second_stable_id | Display 2 (Odyssey G5) | session=display_2 | brightness=84 | contrast=50 | mode=software | automationInterrupted=false
    set: DisplayDimmer.Cli.exe --set-brightness 70 --target dd_your_second_stable_id
    json: DisplayDimmer.Cli.exe --set-brightness 70 --target dd_your_second_stable_id --json
```

Supported target forms:

| Target | Meaning |
|---|---|
| `all` | All currently connected displays. Each display still returns its own success or error result. |
| `primary` | Current Windows primary display, resolved dynamically by the running app at command execution time. |
| `dd_...` target ID | Recommended ID for scripts. Based on Display Dimmer's stable display identity. |
| `display_1`, `display_2`, etc. | Session aliases from `sessionId`; useful for quick tests, but weaker than `dd_...` target IDs. |

Linked display groups also have `dd_...` target IDs in the `linkedGroups` section of `--list-displays --json`. Targeting a linked group expands to its currently connected member displays inside the running Display Dimmer app. Each member still returns its own success or error result.

For scripts and sensor bridges, use the `targetId` value from `--list-displays`. Prefer `dd_...` target IDs. If the only available `targetId` is `display_1`, `display_2`, or another display number, treat it as session-only and rerun `--list-displays` after hotplug, docking, driver updates, or display layout changes.

JSON may include raw `identity` and `deviceName` fields for troubleshooting. They are not stable public script targets. Do not build saved scripts around `\\.\DISPLAY1`-style device names.

To target a specific set of displays, repeat `--target`:

```powershell
DisplayDimmer.Cli.exe --set-brightness 55 --target dd_your_stable_id --target dd_your_second_stable_id
```

Do not use comma-separated target lists. `--target all` must be used by itself.

Important: `primary` is not a stable ID. It is resolved by the running Display Dimmer app when the command executes. If the Windows primary display changes after a restart, dock change, hotplug, or display settings change, `--target primary` follows the new primary display.

Important: `sessionId` values like `display_1` still work, but they are not the ID to save long term. They describe the current Windows display session and can change after hotplug, docking, driver, or layout changes. A `dd_...` target ID is safer because it comes from Display Dimmer's stable display identity.

## Common Examples

List displays in human-readable form:

```powershell
DisplayDimmer.Cli.exe --list-displays
```

List displays as compact JSON:

```powershell
DisplayDimmer.Cli.exe --list-displays --json
```

List displays as readable JSON:

```powershell
DisplayDimmer.Cli.exe --list-displays --pretty
```

Get state for all displays:

```powershell
DisplayDimmer.Cli.exe --get-state --target all --pretty
```

Get state for one display:

```powershell
DisplayDimmer.Cli.exe --get-state --target dd_your_stable_id --pretty
```

Get state for the current primary display:

```powershell
DisplayDimmer.Cli.exe --get-state --target primary --pretty
```

Set one display to 70:

```powershell
DisplayDimmer.Cli.exe --set-brightness 70 --target dd_your_stable_id
```

Set one display to 40 through software/gamma by disabling DDC/CI first:

```powershell
DisplayDimmer.Cli.exe --set-brightness 40 --brightness-mode gamma --target dd_your_stable_id
```

Set one display to 70 through DDC/CI by enabling DDC/CI first:

```powershell
DisplayDimmer.Cli.exe --set-brightness 70 --brightness-mode ddc --target dd_your_stable_id
```

Change only the saved DDC/CI preference:

```powershell
DisplayDimmer.Cli.exe --set-ddc disabled --target dd_your_stable_id
DisplayDimmer.Cli.exe --set-ddc enabled --target dd_your_stable_id
```

Set the current primary display to 70:

```powershell
DisplayDimmer.Cli.exe --set-brightness 70 --target primary
```

Set all displays to 40:

```powershell
DisplayDimmer.Cli.exe --set-brightness 40 --target all
```

Set two specific displays to 55:

```powershell
DisplayDimmer.Cli.exe --set-brightness 55 --target dd_your_stable_id --target dd_your_second_stable_id
```

Raise one display by 10:

```powershell
DisplayDimmer.Cli.exe --adjust-brightness +10 --target dd_your_stable_id
```

Lower one display by 10:

```powershell
DisplayDimmer.Cli.exe --adjust-brightness -10 --target dd_your_stable_id
```

Send a command from a sensor integration:

```powershell
DisplayDimmer.Cli.exe --set-brightness 72 --target dd_your_stable_id --source arduino-sensor
```

Watch Display Dimmer state changes:

```powershell
DisplayDimmer.Cli.exe --watch --json
```

Save brightness intentionally:

```powershell
DisplayDimmer.Cli.exe --set-brightness 70 --target dd_your_stable_id --save
```

Use a longer timeout:

```powershell
DisplayDimmer.Cli.exe --set-brightness 70 --target dd_your_stable_id --timeout 10000
```

## Advanced DDC/CI VCP Commands

VCP commands are for monitor-specific DDC/CI features. They go through the running Display Dimmer app and the same local named pipe, but they are raw hardware reads/writes rather than Display Dimmer's app-owned brightness/contrast path. They do not update Display Dimmer's brightness slider, software/gamma contrast slider, saved brightness/contrast values, schedules, or app rules.

Quick rule: use normal brightness and contrast commands when you want Display Dimmer's sliders, saved state, schedules, app rules, and handoff behavior to stay in sync. Use VCP commands only when you intentionally want a raw monitor DDC/CI feature.

| Goal | Use | What it changes |
|---|---|---|
| Normal Display Dimmer brightness | `--set-brightness <0-100>` | Updates Display Dimmer's tracked brightness and uses the app's normal DDC/CI-or-gamma brightness route. |
| Force software/gamma brightness | `--set-brightness <0-100> --brightness-mode gamma` | Disables DDC/CI first, then updates Display Dimmer brightness through software/gamma. |
| Force DDC/CI brightness | `--set-brightness <0-100> --brightness-mode ddc` | Enables DDC/CI first, then updates Display Dimmer brightness through the normal DDC-capable path. |
| Normal Display Dimmer contrast | `--set-contrast <0-100>` | Updates Display Dimmer's software/gamma contrast state. It does not change the monitor OSD contrast value. |
| Raw monitor brightness VCP | `--set-vcp 0x10 <value>` | Writes monitor hardware brightness directly. The valid range is monitor-reported, often but not always 0-100. It does not update Display Dimmer brightness state or sliders. |
| Raw monitor contrast VCP | `--set-vcp ddc-contrast <value>` | Writes monitor hardware contrast directly. The valid range is monitor-reported, often but not always 0-100. It does not update Display Dimmer contrast state or sliders. |
| DDC/CI preference only | `--set-ddc enabled` / `--set-ddc disabled` | Changes Display Dimmer's saved DDC/CI preference without setting a new brightness value. |

Use normal Display Dimmer commands for app-owned brightness and contrast:

```powershell
DisplayDimmer.Cli.exe --set-brightness 70 --target dd_your_stable_id
DisplayDimmer.Cli.exe --set-contrast 50 --target dd_your_stable_id
```

If DDC/CI is enabled and healthy for a display, normal `--set-brightness` can still use DDC/CI internally because that is Display Dimmer's regular brightness route. If DDC is disabled, unavailable, unreliable, or not appropriate, Display Dimmer can use software/gamma fallback instead. When the command applies, it updates Display Dimmer's tracked brightness state and participates in the same UI, `--save`, schedule, and app-rule handoff model described in Automation Interaction. `--source cli` is the manual-override path; named sources are cooperative external automation.

Use `--brightness-mode` when a script intentionally wants to switch the display route before setting brightness:

```powershell
DisplayDimmer.Cli.exe --set-brightness 35 --brightness-mode gamma --target dd_your_stable_id
DisplayDimmer.Cli.exe --set-brightness 35 --brightness-mode ddc --target dd_your_stable_id
```

`--brightness-mode gamma` and `--brightness-mode software` disable DDC/CI first, transition the current level to software/gamma, then set the requested brightness. `--brightness-mode ddc` enables DDC/CI first, then sets the requested brightness through Display Dimmer's normal DDC-capable brightness path. These commands change the saved DDC/CI preference for that display.

Use `--set-ddc` when a script only needs to change the saved DDC/CI preference:

```powershell
DisplayDimmer.Cli.exe --set-ddc disabled --target dd_your_stable_id
DisplayDimmer.Cli.exe --set-ddc enabled --target dd_your_stable_id
```

Disabling DDC/CI through `--set-ddc` uses the same safe DDC-off-to-gamma transition as Settings. Enabling DDC/CI queues a reassert of the current Display Dimmer level to hardware when display control is enabled. `--set-ddc` saves the preference automatically, without `--save`.

### Extra-Dark Dimming

Most scripts should use normal `--set-brightness`. Use this pattern when you intentionally want to dim lower than Display Dimmer's normal brightness range, such as a hotkey, macro button, no-motion dimmer, or other local automation:

1. Set brightness through the DDC/CI route.
2. Disable DDC/CI so Display Dimmer keeps the same low level through software/gamma.

This pattern requires Display Dimmer > Settings > General > **Reset DDC/CI displays to default brightness on exit** to be turned off. If that setting is on, disabling DDC/CI can restore monitor hardware brightness to 100 and prevent the DDC + gamma stack from working. See [Automation Recipes](../examples/automation-recipes/README.md#extra-dark-dimming) for the copy-paste commands, DDC/CI support notes, and restore behavior.

Normal `--set-contrast` stays on Display Dimmer's software/gamma contrast path. It does not change the monitor's hardware OSD contrast setting.

Use VCP only when you intentionally want to read or write the monitor's raw DDC/CI hardware value:

```powershell
DisplayDimmer.Cli.exe --set-vcp ddc-contrast 50 --target dd_your_stable_id
```

`--set-vcp ddc-contrast` writes hardware VCP `0x12` directly. It does not update Display Dimmer's normal software/gamma contrast slider or saved contrast setting. Use `--set-contrast` when you want Display Dimmer's in-app contrast state to change.

Use `--set-brightness` for normal brightness control. You can still send numeric raw VCP `0x10`, but treat it as a monitor diagnostic/escape hatch rather than a named brightness command. `--set-vcp 0x10` writes hardware brightness directly and does not update Display Dimmer's normal brightness slider or saved brightness setting.

Raw DDC/CI VCP commands require the monitor's DDC/CI path to respond, but they do not require Display Dimmer's DDC brightness preference to be enabled. They do not switch the display into DDC brightness mode, do not use software/gamma fallback, and do not participate in automation handoff. `--force` does not override disconnected displays, unsupported monitor features, DDC/CI timeouts, or failed monitor reads/writes.

Use VCP for advanced monitor controls such as input source, monitor audio, raw hardware contrast, color gains, color presets, power mode, and display usage time.

Inspect known VCP controls first:

```powershell
DisplayDimmer.Cli.exe --list-vcp --target all --pretty
DisplayDimmer.Cli.exe --list-vcp --target dd_your_stable_id --pretty
```

`--list-vcp` lists Display Dimmer-supported VCP features and adds monitor capability hints when the display returns a capabilities string. It is not a full raw MCCS capability dump.

Capability hints are monitor-specific and advisory. If `vcpCapabilityAdvertised` is `null`, Display Dimmer did not get a reliable capabilities answer for that display. Display Dimmer still enforces its own VCP allowlist, force requirements, target restrictions, DDC/VCP timeouts, and verification policy. For writes where a capabilities string is available, Display Dimmer checks whether the requested feature/value is advertised by the monitor. Some monitors do not report reliable capabilities, so scripts should still handle VCP write failures.

In human `--list-vcp --pretty` output, `advertised=true` means the monitor's capabilities string reported that VCP feature. `advertised=false` means Display Dimmer knows the VCP code, but the monitor did not advertise it. `advertised=null` in JSON means Display Dimmer did not get a reliable capability answer for that display.

Read a VCP feature:

```powershell
DisplayDimmer.Cli.exe --get-vcp input-source --target all --pretty
DisplayDimmer.Cli.exe --get-vcp input-source --target dd_your_stable_id --pretty
DisplayDimmer.Cli.exe --get-vcp 0xC0 --target dd_your_stable_id --pretty
```

Write an allowed VCP feature:

```powershell
DisplayDimmer.Cli.exe --set-vcp input-source hdmi1 --target dd_your_stable_id --force
DisplayDimmer.Cli.exe --set-vcp volume 25 --target dd_your_stable_id
DisplayDimmer.Cli.exe --set-vcp volume 25 --target dd_your_stable_id --target dd_your_second_stable_id
DisplayDimmer.Cli.exe --set-vcp ddc-contrast 50 --target dd_your_stable_id
```

Numeric VCP `0x10` remains available for advanced raw monitor brightness diagnostics:

```powershell
DisplayDimmer.Cli.exe --set-vcp 0x10 70 --target dd_your_stable_id
```

Raw numeric `0x10` is accepted, but it is intentionally not shown in `--list-vcp` because normal brightness control should use `--set-brightness`.

`--set-vcp` allows multi-target writes only for numeric raw VCP `0x10`, raw hardware contrast (`ddc-contrast`, `0x12`), and monitor volume (`0x62`). High-impact commands such as input switching, power mode, mute/screen blank, color presets, and RGB gains require a target that resolves to exactly one display even when `--force` is used.

`--force` is required for high-impact VCP writes such as input switching, power mode, color presets, RGB gains, and mute/screen-blank controls. Without `--force`, Display Dimmer only allows lower-risk continuous controls such as monitor volume, raw DDC contrast, and numeric raw VCP `0x10`.

Supported names:

| Name | Code | Write | Common use |
|---|---:|---|---|
| `ddc-contrast` | `0x12` | yes | raw monitor hardware contrast |
| `color-preset` | `0x14` | yes | monitor color preset |
| `red-gain` | `0x16` | yes | red gain |
| `green-gain` | `0x18` | yes | green gain |
| `blue-gain` | `0x1A` | yes | blue gain |
| `input-source` | `0x60` | yes | VGA/DVI/DisplayPort/HDMI input switching by named values; use numeric values for other monitor-specific inputs. |
| `volume` | `0x62` | yes | monitor audio volume |
| `mute` | `0x8D` | yes | monitor audio mute |
| `usage-time` | `0xC0` | read only | display usage time |
| `power-mode` | `0xD6` | yes | monitor power mode |
| `mccs-version` | `0xDF` | read only | MCCS/VCP version |

Common `input-source` values are monitor-dependent, but many displays use `0x0F` for DisplayPort-1, `0x10` for DisplayPort-2, `0x11` for HDMI-1, and `0x12` for HDMI-2.

VCP `0x10` is intentionally not listed as a named brightness feature. Use `--set-brightness` for normal brightness control; use numeric `0x10` only when you intentionally want a raw VCP write.

Common `power-mode` values are also monitor-dependent. Some displays use `0x01` for on and `0x04` or `0x05` for standby/off. Power-mode writes are intentionally not shown as copy-paste examples because a monitor in standby may not accept a later DDC command to wake back up.

Audio mute is available as an advanced raw VCP control when supported by the monitor. On some monitors this VCP code can blank the screen rather than only muting audio, so it is treated as a high-impact command and requires `--force`.

Display Dimmer intentionally blocks unsupported raw VCP writes such as factory reset codes. If a monitor-specific command is needed later, add it deliberately instead of exposing every possible code.

VCP writes are serialized with other local API commands and rate-limited before reaching DDC/CI. This avoids flooding slow monitors when a script repeats a command quickly. `--set-vcp` is independent of Display Dimmer's DDC brightness preference, but the monitor's DDC/CI path still has to accept the raw read/write. `--force` does not override a disconnected display, unsupported feature, timeout, or failed monitor write.

## Output Modes

Human output is meant for a user at a terminal:

```text
Applied brightness to 1 of 1 display(s).
  ok     dd_your_stable_id | Display 1 (Odyssey G61SD) | brightness=70 | previous=84 | mode=software
```

JSON output is meant for scripts:

```powershell
DisplayDimmer.Cli.exe --set-brightness 70 --target dd_your_stable_id --json
```

Compact JSON is one line. Pretty JSON is easier to read:

```powershell
DisplayDimmer.Cli.exe --get-state --target dd_your_stable_id --pretty
```

## JSON Response Shape

Every structured response includes:

```json
{
  "apiVersion": 1,
  "success": true,
  "partial": false,
  "exitCode": 0,
  "errorCode": null,
  "message": "Display state returned.",
  "automationInterrupted": false,
  "displays": [],
  "linkedGroups": [],
  "results": []
}
```

`displays` is used by `--list-displays` and `--get-state` for physical displays.

`linkedGroups` is used by `--list-displays`, `--get-state`, and `--watch` snapshots for linked display group targets. It is separate from `displays` so existing scripts that enumerate physical displays keep the same meaning.

`results` is used by brightness, contrast, external-brightness, DDC preference, and VCP commands.

## Display Fields

Example display object:

```json
{
  "id": "dd_your_stable_id",
  "targetId": "dd_your_stable_id",
  "sessionId": "display_1",
  "identity": "\\\\?\\DISPLAY#SAM7779#5&1B564525&0&UID4355#{E6F07B5F-EE97-4A90-B076-33F57BF4EAA7}",
  "name": "Display 1 (Odyssey G61SD)",
  "deviceName": "\\\\.\\DISPLAY1",
  "isConnected": true,
  "isPrimary": true,
  "controlEnabled": true,
  "controlMode": "software",
  "ddcEnabled": false,
  "ddcWriteEnabled": false,
  "supportsBrightness": true,
  "supportsContrast": true,
  "brightness": 84,
  "contrast": 50,
  "scheduleActive": true,
  "scheduleInterrupted": false,
  "perAppActive": false,
  "perAppInterrupted": false,
  "automationInterrupted": false,
  "externalBrightnessActive": false,
  "externalBrightness": null,
  "externalBrightnessSource": null
}
```

Key fields:

| Field | Meaning |
|---|---|
| `targetId` | Recommended value to copy into CLI commands. Prefer `dd_...` values for saved scripts. If this is `display_1`, treat it as session-only. |
| `sessionId` | Alias such as `display_1`; useful for quick tests, weaker than `dd_...` target IDs. |
| `identity` | Raw Display Dimmer/Windows identity for diagnostics. Not a public stable target form. |
| `deviceName` | Windows display device name for diagnostics. Do not use `\\.\DISPLAY1`-style names in saved scripts. |
| `isPrimary` | Whether this is the current Windows primary display. |
| `controlMode` | `ddc`, `software`, `disabled`, or `unknown`. |
| `brightness` | Current Display Dimmer brightness state. |
| `scheduleActive` | A schedule is currently active for this display. |
| `scheduleInterrupted` | A manual/script override has paused schedule control for this display. |
| `perAppActive` | An app rule is currently active for this display. |
| `perAppInterrupted` | A manual/script override has suspended app-rule control for this display. |
| `automationInterrupted` | `scheduleInterrupted || perAppInterrupted`. |
| `externalBrightnessActive` | A cooperative external controller has a fresh handoff value for this display. |
| `externalBrightness` | The latest cooperative external brightness value, when present. |
| `externalBrightnessSource` | Source name that supplied the cooperative external brightness value. |

## Linked Group Fields

Example linked group object:

```json
{
  "id": "dd_linked_group_id",
  "targetId": "dd_linked_group_id",
  "identity": "__LINKED_DISPLAYS__:desk",
  "name": "Desk pair",
  "isEnabled": true,
  "isConnected": true,
  "connectedMemberCount": 2,
  "totalMemberCount": 2,
  "memberTargetIds": ["dd_first_display", "dd_second_display"],
  "memberIdentities": ["display identity 1", "display identity 2"]
}
```

Use `targetId` to control the linked group. Display Dimmer expands the group to currently connected member displays and deduplicates overlapping targets before writing. Each member still returns its own success or error result.

## Brightness Result Fields

Example result:

```json
{
  "displayId": "dd_your_stable_id",
  "targetId": "dd_your_stable_id",
  "sessionId": "display_1",
  "identity": "\\\\?\\DISPLAY#...",
  "deviceName": "\\\\.\\DISPLAY1",
  "name": "Display 1 (Odyssey G61SD)",
  "success": true,
  "previousBrightness": 84,
  "brightness": 70,
  "controlMode": "software",
  "errorCode": null,
  "message": "Applied."
}
```

For `--target all` or repeated `--target`, inspect every item in `results`. Some displays can succeed while others fail. `Applied.` means Display Dimmer accepted the command and completed the app-side apply path for that display. DDC/CI monitors can still have visible hardware latency after the CLI returns.

## VCP Result Fields

Example result:

```json
{
  "displayId": "dd_your_stable_id",
  "targetId": "dd_your_stable_id",
  "sessionId": "display_1",
  "identity": "\\\\?\\DISPLAY#...",
  "deviceName": "\\\\.\\DISPLAY1",
  "name": "Display 1 (Odyssey G61SD)",
  "success": true,
  "vcpCode": 96,
  "vcpCodeHex": "0x60",
  "vcpName": "input-source",
  "vcpDescription": "input source",
  "vcpCodeType": "nonContinuous",
  "previousVcpValue": 15,
  "previousVcpValueHex": "0xF",
  "vcpValue": 17,
  "vcpValueHex": "0x11",
  "vcpCapabilityAdvertised": true,
  "vcpRequiresForce": true,
  "vcpVerified": false,
  "vcpVerificationStatus": "skippedAfterHardwareStateChange",
  "controlMode": "ddc",
  "errorCode": null,
  "message": "VCP feature write accepted."
}
```

`vcpMax` and `vcpMaxHex` are returned for continuous controls such as numeric raw VCP `0x10`, raw DDC contrast, monitor volume, and RGB gains. They are intentionally omitted for non-continuous controls such as input source, mute, power mode, and color preset because monitor APIs do not define a reliable maximum for those controls.

If verification is requested and monitor readback does not match the requested value, Display Dimmer includes `vcpActualValue` and `vcpActualValueHex` with the value that was read back.

## Exit Codes

| Code | Meaning |
|---:|---|
| `0` | Success. |
| `1` | Invalid arguments. |
| `2` | Display Dimmer app or Local automation unavailable. |
| `3` | Target not found. |
| `4` | Unsupported command or operation. |
| `5` | Operation failed. |
| `6` | Partial success. |
| `7` | Timeout. |

Scripts should check both the process exit code and the JSON response.

PowerShell example:

```powershell
$json = DisplayDimmer.Cli.exe --set-brightness 70 --target dd_your_stable_id --json
$exit = $LASTEXITCODE
$response = $json | ConvertFrom-Json

if ($exit -ne 0 -or -not $response.success) {
    Write-Error "Display Dimmer command failed: $($response.errorCode) $($response.message)"
}
```

## Automation Interaction

Command-line brightness changes are live-only by default. `--source` decides whether the command behaves like a manual override or like cooperative external automation.

### Manual Override Mode

By default, `--set-brightness` takes control immediately. Pass `--source cli` when you want that intent to be explicit in a saved script:

```powershell
DisplayDimmer.Cli.exe --set-brightness 65 --target dd_your_stable_id --source cli
```

In this mode:

- A script can send `--set-brightness` without the next schedule tick immediately snapping brightness back.
- Active schedules become interrupted for the targeted display identities.
- Active app rules become suspended for the targeted display identities.
- The app UI and `--get-state` expose that interruption.
- Saved brightness changes only when `--save` is passed.
- The override state is owned by the running app session and follows the same resume/apply behavior as existing slider and hotkey overrides.

Before a manual/script override:

```json
{
  "scheduleActive": true,
  "scheduleInterrupted": false,
  "automationInterrupted": false
}
```

After a manual/script override:

```json
{
  "scheduleActive": true,
  "scheduleInterrupted": true,
  "automationInterrupted": true
}
```

The schedule still matches the current time, but this display is being held by a manual/script override. To resume schedules from the UI, open Schedules and click Apply. Display Dimmer clears the interruption and forces the scheduler to reassert the active rule.

### Cooperative External Automation Mode

Use a named source such as `--source desk-light-sensor` when the script should cooperate with Display Dimmer schedules and app rules:

```powershell
DisplayDimmer.Cli.exe --set-brightness 65 --target dd_your_stable_id --source desk-light-sensor
```

If no schedule or app rule owns the target, the command can apply immediately. If Display Dimmer automation already owns the target, the command stands down and updates the external handoff value instead of interrupting the rule. Use `--update-external-brightness` while standing by when the script only needs to keep that handoff value fresh.

## Sensor And External Automation Pattern

Decide first whether the sensor should win over Display Dimmer automation or cooperate with it.

### Sensor Wins / Manual Override

Use this mode when a script should dim or restore immediately even if a schedule or app rule is active:

```powershell
DisplayDimmer.Cli.exe --set-brightness 65 --target dd_your_stable_id --source cli
```

This behaves like moving the Display Dimmer slider or using a hotkey. It interrupts schedules and suspends app rules for the targeted display identities until you resume them or the relevant rule is reapplied.

### Cooperative Sensor

A cooperative sensor script usually works best like this:

1. Read sensor value.
2. Smooth/filter noisy input.
3. Map the value to `0-100` brightness.
4. Send `--set-brightness <value> --target <target> --source <name>` while no Display Dimmer automation owns the target.
5. Avoid sending every tiny value change.
6. Poll `--get-state` before sending another command.
7. Enter standby when Display Dimmer automation is taking control.
8. Keep reading the sensor while standing by.
9. While standing by, refresh the latest desired value with `--update-external-brightness`.
10. Resume sensor control after Display Dimmer automation releases the target.

Treat either of these states as "Display Dimmer automation is taking control":

```json
{
  "scheduleActive": true,
  "scheduleInterrupted": false
}
```

```json
{
  "perAppActive": true,
  "perAppInterrupted": false
}
```

Do not rely only on the combined `automationInterrupted` field when deciding whether an app rule should take over. A schedule can still be interrupted while an app rule is correctly taking control.

Recommended priority for cooperative sensor scripts:

- If `perAppActive=true` and `perAppInterrupted=false`, stand by.
- If the sensor has already sent a command and then sees `scheduleActive=true` and `scheduleInterrupted=false`, stand by.
- While standing by, keep polling `--get-state`.
- While standing by, keep `--update-external-brightness` fresh so automation release can hand off directly to the sensor value.
- When neither an uninterrupted app rule nor an uninterrupted schedule is active, send the latest sensor brightness and take control again.
- While the sensor is active, reassert if `--get-state` shows the live brightness differs from the sensor's desired value. This covers manual slider movement while the sensor is running.

Example cooperative apply:

```powershell
DisplayDimmer.Cli.exe --set-brightness 65 --target dd_your_stable_id --source desk-light-sensor
```

Arduino example integrations:

- [Arduino light sensor](../examples/arduino-light-sensor) - cooperative sensor handoff by default.
- [Arduino motion sensor](../examples/arduino-motion-sensor) - no-motion manual override by default.

### Apply Now Versus Update Intent

Use `--set-brightness ... --source cli` when the external controller should take control immediately and interrupt Display Dimmer automation:

```powershell
DisplayDimmer.Cli.exe --set-brightness 65 --target dd_your_stable_id --source cli
```

Use `--set-brightness ... --source <name>` when the external controller is cooperative and should stand down if Display Dimmer automation already owns the display:

```powershell
DisplayDimmer.Cli.exe --set-brightness 65 --target dd_your_stable_id --source desk-light-sensor
```

Use `--update-external-brightness` when automation currently owns the display and the external controller only needs to keep its latest desired value fresh:

```powershell
DisplayDimmer.Cli.exe --update-external-brightness 65 --target dd_your_stable_id --source desk-light-sensor
```

`--update-external-brightness` does not move the monitor and does not interrupt schedules or app rules. It stores a short-lived external intent in the running app. When a schedule/app rule later releases that display, Display Dimmer can resume directly to the fresh external value instead of briefly restoring the last manual baseline first.

The intent is intentionally short-lived. A sensor bridge should refresh it while standing by. If the bridge exits or stops sending heartbeats, Display Dimmer falls back to normal saved/manual restore behavior.

## Task Scheduler Example

In the Task Scheduler UI, set **Program/script** to the path returned by:

```powershell
$cliPath = (Get-Command DisplayDimmer.Cli.exe -ErrorAction Stop).Source
$cliPath
```

Arguments:

```text
--set-brightness 40 --target dd_your_stable_id --source cli
```

Use "Run only when user is logged on" for display control tasks. Windows display APIs generally do not behave correctly from service/session 0 tasks.

## Watch Stream

Use:

```powershell
DisplayDimmer.Cli.exe --watch --json
```

`--watch` emits JSON Lines: one compact JSON object per line. Parse each line as a separate JSON document; do not try to parse the whole command output as one JSON array.

The stream starts with a `snapshot` event, then emits `stateChanged` only when Display Dimmer's tracked state changes. Display entries use the same fields as `--get-state`, including `targetId`, `sessionId`, `identity`, `name`, `brightness`, `contrast`, `controlMode`, `scheduleActive`, `scheduleInterrupted`, `perAppActive`, `perAppInterrupted`, and `automationInterrupted`.

Initial snapshot shape:

```json
{"apiVersion":1,"event":"snapshot","timestampUtc":"2026-05-20T00:00:00Z","state":{"automationInterrupted":false,"displays":[]}}
```

State change shape:

```json
{"apiVersion":1,"event":"stateChanged","timestampUtc":"2026-05-20T00:00:01Z","state":{"automationInterrupted":true,"displays":[]}}
```

PowerShell example:

```powershell
$cli = "DisplayDimmer.Cli.exe"

& $cli --watch --json | ForEach-Object {
    if (-not [string]::IsNullOrWhiteSpace($_)) {
        $event = $_ | ConvertFrom-Json

        if ($event.event -eq "snapshot") {
            Write-Host "Initial state: $($event.state.displays.Count) display(s)"
        }

        if ($event.event -eq "stateChanged") {
            foreach ($display in $event.state.displays) {
                Write-Host "$($display.name): brightness=$($display.brightness) mode=$($display.controlMode)"
            }
        }
    }
}
```

Sensor standby example:

```powershell
DisplayDimmer.Cli.exe --watch --json | ForEach-Object {
    if (-not [string]::IsNullOrWhiteSpace($_)) {
        $event = $_ | ConvertFrom-Json

        if ($event.state) {
            foreach ($display in $event.state.displays) {
                $perAppOwns = $display.perAppActive -and -not $display.perAppInterrupted
                $scheduleOwns = $display.scheduleActive -and -not $display.scheduleInterrupted

                if ($perAppOwns -or $scheduleOwns) {
                    Write-Host "$($display.name): stand by and send --update-external-brightness."
                } else {
                    Write-Host "$($display.name): sensor may send --set-brightness."
                }
            }
        }
    }
}
```

Notes:

- `--watch` requires `--json`.
- `--pretty` is not valid with `--watch` because JSON Lines must stay one object per line.
- `--target` is not supported for watch in this build.
- For multi-display sensors, make the standby decision per display. A fullscreen app rule on display 2 should not stop sensor control for display 1.
- The stream is local-only and uses the same current-user named pipe as one-shot commands.
- The stream reports the state Display Dimmer is already tracking. It is not guaranteed hardware readback and does not poll DDC/CI or gamma hardware directly.
- Unchanged state is coalesced, so scripts should not expect periodic heartbeat events.
- If Display Dimmer is not running, the CLI returns the normal `appUnavailable` JSON error and exits.
- Stop the command with Ctrl+C or by terminating the process.

## PowerShell Tips

For manual reading, use `--pretty`:

```powershell
DisplayDimmer.Cli.exe --get-state --target all --pretty
```

For scripts, use `--json`:

```powershell
$state = DisplayDimmer.Cli.exe --get-state --target all --json | ConvertFrom-Json
```

Relative adjustments with negative numbers are supported:

```powershell
DisplayDimmer.Cli.exe --adjust-brightness -10 --target dd_your_stable_id
```

If another script asks for a CLI path, resolve the installed command:

```powershell
$cliPath = (Get-Command DisplayDimmer.Cli.exe -ErrorAction Stop).Source
```

## Troubleshooting

### Start With A Diagnostic Command

When a command does not behave as expected, rerun it with JSON:

```powershell
DisplayDimmer.Cli.exe --set-brightness 45 --target dd_your_stable_id --source cli --json --pretty
```

Check:

- `success`: overall success.
- `partial`: at least one target succeeded and at least one failed.
- `exitCode`: process result for scripts.
- `errorCode`: stable error name.
- `message`: human-readable summary.
- `results`: per-display target, mode, value, success, and error details.

### PowerShell Cannot Find DisplayDimmer.Cli.exe

Make sure Display Dimmer is installed or updated from the Microsoft Store and has been started at least once.

Check the installed command path:

```powershell
(Get-Command DisplayDimmer.Cli.exe -ErrorAction Stop).Source
```

If this fails, check Windows app execution aliases or open Display Dimmer > Settings > General > Advanced > Local automation > Manage... and copy a command from the Local automation window.

### Display Dimmer is not running

The CLI returns exit code `2` with `errorCode: "appUnavailable"` when the local automation pipe does not exist.

Human output:

```text
Display Dimmer CLI error: Display Dimmer is not running, not ready, Local automation is locked, or Local automation is turned off. Open Display Dimmer > Settings > General > Advanced > Local automation > Manage..., unlock Pro if prompted, and turn on Local automation.
```

JSON output:

```json
{
  "success": false,
  "exitCode": 2,
  "errorCode": "appUnavailable",
  "message": "Display Dimmer is not running, not ready, Local automation is locked, or Local automation is turned off. Open Display Dimmer > Settings > General > Advanced > Local automation > Manage..., unlock Pro if prompted, and turn on Local automation."
}
```

Start Display Dimmer from the Start menu or tray, open Display Dimmer > Settings > General > Advanced > Local automation > Manage..., unlock Pro if prompted, turn on **Local automation**, then run the CLI command again.

If this happens from Task Scheduler but not from a normal PowerShell window, the task is probably running in the wrong user/session. Run the task as the same Windows user as Display Dimmer and use "Run only when user is logged on".

### JSON output is missing expected fields

The CLI is probably talking to a different running app version.

The running app owns the Local automation server and response shape. Update Display Dimmer from the Microsoft Store, restart Display Dimmer, and use the CLI from the same release.

### Target not found

Run:

```powershell
DisplayDimmer.Cli.exe --list-displays
```

Then use the displayed `targetId`. Prefer a `dd_...` target ID, such as `dd_your_stable_id`, for saved scripts. If the displayed `targetId` is `display_1`, rerun `--list-displays` after display changes before relying on it.

For linked display groups, copy the group's `targetId` from `linkedGroups` in JSON output. If a linked group has no connected members, the group target can be present but fail when a command expands it.

### Partial success

For `--target all`, repeated `--target`, or linked group targets, one display can succeed while another fails.

Use:

```powershell
DisplayDimmer.Cli.exe --set-brightness 45 --target all --json --pretty
```

Then inspect each item in `results`. Common examples are a linked group with one available member and one missing member, or a raw VCP command where one monitor has a usable DDC/CI path and another does not.

### Command succeeds but brightness does not move

Check the command source and automation state.

If you used a named source such as `--source desk-light-sensor`, Display Dimmer may have treated the command as cooperative external automation. When an uninterrupted schedule or app rule owns the target, the command can refresh the handoff value without moving the display.

By default, `--set-brightness` acts like a manual override and can interrupt Display Dimmer automation. Pass `--source cli` when you want that intent to be explicit in a saved script:

```powershell
DisplayDimmer.Cli.exe --set-brightness 45 --target dd_your_stable_id --source cli
```

If the command uses raw VCP, remember that VCP writes do not update Display Dimmer's sliders or saved brightness/contrast state.

### Schedule resumes, then immediately pauses again

Something is still sending external brightness commands.

The sensor bridge needs to stand by when it sees `scheduleActive=true` and `scheduleInterrupted=false`. If it keeps sending manual override commands, each command is treated as a new manual/script override and pauses the schedule again. Cooperative sensor scripts should use a named `--source <name>` and `--update-external-brightness` while standing by.

### App rule starts, then immediately pauses again

Something is still sending external brightness commands.

A sensor script needs to stand by when `perAppActive=true` and `perAppInterrupted=false`. Otherwise the next manual override command will suspend the app rule again. Cooperative sensor scripts should use a named `--source <name>` and `--update-external-brightness` while standing by.

### Command succeeds but hardware changes slowly

DDC/CI monitors can be slow or flaky. Display Dimmer updates its cached app state after a short coalescing window, then lets delayed hardware DDC failures flow through the existing diagnostics pipeline.

For rapid script writes, absolute brightness/contrast commands use the latest accepted value. Relative brightness/contrast adjustments preserve the pending adjustment intent before Display Dimmer applies the final value.

### VCP command fails

VCP commands require the target monitor's DDC/CI path to respond. They do not require Display Dimmer's DDC brightness preference to be enabled, and they do not change that saved preference. `--force` allows high-impact writes after you choose a target that resolves to one display, but it does not override disconnected displays, unsupported monitor features, DDC/CI timeouts, or monitor read/write failures.

If `--list-vcp --pretty` shows `advertised=false`, Display Dimmer knows the VCP code but the monitor did not advertise it in its capabilities string. The monitor may still accept some features, but scripts should handle failure.

High-impact VCP commands such as input switching, power mode, mute/screen blank, color presets, and RGB gains require a target that resolves to exactly one display. Linked groups that expand to multiple displays are rejected for these high-impact writes.

### Watch command seems quiet

`--watch --json` emits an initial `snapshot`, then emits `stateChanged` only when Display Dimmer's tracked state changes. It is not a periodic heartbeat.

`--pretty` is not valid with `--watch`, and per-target watch filtering is not implemented in this build.

## Current Limits

- The app must already be running.
- `--target primary` is a dynamic selector, not a stable automation ID.
- `--watch` streams full state changes only in this build; per-target watch filtering is not implemented.
- Brightness commands use Display Dimmer's normal brightness path: DDC/CI when enabled and healthy, software/gamma fallback when needed.
- `--brightness-mode` can switch one `--set-brightness` command to software/gamma or DDC first; this changes the saved DDC/CI preference for that display.
- `--set-ddc` changes the saved DDC/CI preference without applying a new brightness value.
- Contrast commands use Display Dimmer's normal software/gamma contrast path. They are live-only and do not support `--save`.
- VCP commands are advanced DDC/CI commands. Support and values are monitor-specific. Multi-target `--set-vcp` is allowed only for numeric raw VCP `0x10`, raw DDC contrast, and monitor volume; high-impact writes stay single-display only.
- Transitions/fades are not part of v1.
- Network APIs are not part of v1.
- `dd_...` target IDs are intended for saved scripts on the same machine, but they are not a permanent cross-hardware contract.
- Normal brightness/contrast success means Display Dimmer completed the app-side apply path and updated its cached state; DDC/CI monitors can still have visible hardware latency. VCP success means the allowed DDC/CI VCP read/write call was accepted by the monitor path, not guaranteed visible hardware behavior.

## Recommended v1 Contract

For external tools, use this small stable subset first:

```powershell
--list-displays --json
--get-state --target <target> --json
--set-brightness <0-100> --target <target> --source cli --json
--set-brightness <0-100> --brightness-mode gamma|ddc --target <target> --json
--adjust-brightness <-100..100> --target <target> --source cli --json
--set-ddc enabled|disabled --target <target> --json
--set-contrast <0-100> --target <target> --json
--adjust-contrast <-100..100> --target <target> --json
```

Repeat `--target` when a script should affect a specific set of displays:

```powershell
--set-brightness <0-100> --target <target-a> --target <target-b> --json
```

Use `--save` only when you explicitly want to change saved Display Dimmer brightness settings.

Use VCP commands only for advanced monitor-specific workflows:

```powershell
--list-vcp --target <target> --json
--get-vcp input-source --target <target> --json
--set-vcp 0x10 70 --target <target> --json
--set-vcp ddc-contrast 50 --target <target> --json
--set-vcp input-source hdmi1 --target <single-target> --force --json
--set-vcp volume 25 --target <target-a> --target <target-b> --json
```


