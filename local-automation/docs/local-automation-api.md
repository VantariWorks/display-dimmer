# Control Display Dimmer From Local Scripts

You can control Display Dimmer from local scripts and helper apps with the Display Dimmer command-line tool (`DisplayDimmer.Cli.exe`).

Local automation is a Display Dimmer Pro feature.

Display Dimmer 2.2.10 adds temperature and blue light filter control through API **1.1**. The compatible wire protocol stays at `apiVersion: 1`, and `--api-version` still prints `1`. Use the running app's JSON `apiRevision` and `capabilities` to detect temperature support; missing metadata from an older app is not support.

Display Dimmer **2.2.11** adds conditional brightness automation resume in API **1.2**. Basic idle dim/restore of displays without an active rule works with 2.2.10; dimming through an active rule and then resuming it requires a running 2.2.11 or later app advertising `resume-automation`.

This works well for:

- PowerShell scripts
- C# apps
- Task Scheduler
- light sensors
- motion sensors
- Stream Deck or similar macro tools
- other local automation software

The command-line tool sends requests to the already-running Display Dimmer app. Display Dimmer still handles monitor discovery, DDC/CI, software dimming, schedules, app rules, hotkeys, and display identity.

## Quick Start

Install or update Display Dimmer from the Microsoft Store, then start Display Dimmer from the Start menu or tray.

Open Display Dimmer > Settings > General > Advanced > Local automation > Manage..., unlock Pro if prompted, and turn on **Local automation**. You can also use that window to copy display target IDs.

Open PowerShell and confirm the Display Dimmer command-line tool is available:

List displays:

```powershell
DisplayDimmer.Cli.exe --list-displays
```

Copy a `targetId`. Prefer a `dd_...` target ID for scripts you plan to keep:

```text
dd_your_stable_id
```

Set brightness:

```powershell
DisplayDimmer.Cli.exe --set-brightness 70 --target dd_your_stable_id
```

Get state:

```powershell
DisplayDimmer.Cli.exe --get-state --target dd_your_stable_id --pretty
```

For scripts, add JSON:

```powershell
DisplayDimmer.Cli.exe --set-brightness 70 --target dd_your_stable_id --json
```

## Which Command Should I Use?

| Goal | Command pattern | Notes |
| --- | --- | --- |
| Find display and linked group target IDs | `--list-displays` | Use `dd_...` IDs for scripts you plan to keep. |
| Set brightness right now | `--set-brightness <0-100> --target <target>` | Live-only unless `--save` is added. |
| Adjust brightness up/down | `--adjust-brightness <-100..100> --target <target>` | Live-only unless `--save` is added. |
| Save brightness as the Display Dimmer setting | `--set-brightness <0-100> --target <target> --save` | Changes saved app settings. |
| Override schedules/app rules | `--set-brightness <0-100> --target <target> --source cli` | Same behavior when `--source` is omitted. |
| Request brightness automation resume | `--resume-automation --target <target> --expected-brightness <0-100>` | If tracked brightness matches, clears the brightness interruption and requests rule reevaluation. Use only after recording that your temporary override interrupted an unpaused rule. API 1.2. |
| Cooperate with schedules/app rules | `--set-brightness <0-100> --target <target> --source <name>` | Applies when no rule owns brightness; otherwise stands down and refreshes handoff intent. |
| Keep a sensor handoff value fresh | `--update-external-brightness <0-100> --target <target> --source <name>` | Does not move the display or interrupt automation. |
| Set warmer screen colors | `--set-temperature 4000 --temperature-unit kelvin --target <target>` | Temporary by default; manual temperature-only control. |
| Adjust warmth | `--adjust-temperature -200 --temperature-unit kelvin --target <target>` | Negative Kelvin deltas select warmer colors. |
| Save manual temperature | `--set-temperature -50 --target <target> --save` | Queues persistence of the temperature baseline only. |
| Release manual temperature | `--resume-temperature --target <target>` | Resumes temperature ownership without changing brightness interruption. |
| Keep a temperature handoff fresh | `--update-external-temperature 4000 --temperature-unit kelvin --target <target> --source <name>` | Standby intent only; requires a named non-`cli` source. |
| Read current state for a script | `--get-state --target <target> --json` | Includes brightness, contrast, temperature, control mode, and separate temperature ownership. |
| Watch state changes | `--watch --json` | Streams JSON Lines until stopped. |
| Force software/gamma brightness route | `--set-brightness <0-100> --brightness-mode gamma --target <target>` | Safely disables DDC/CI, then applies the requested gamma brightness. |
| Force DDC/CI brightness route | `--set-brightness <0-100> --brightness-mode ddc --target <target>` | Enables DDC/CI first for that display. |
| Change saved DDC/CI preference | `--set-ddc enabled\|disabled --target <target>` | An enabled-to-disabled transition also sets and saves gamma brightness at a safe 100% baseline. |
| Use Display Dimmer contrast | `--set-contrast <0-100> --target <target>` | Uses Display Dimmer's software/gamma contrast path. |
| Use raw monitor DDC/CI features | `--get-vcp` / `--set-vcp` | Advanced monitor-specific controls; high-impact writes require `--force`. |

### PowerShell Cannot Find The Command

If PowerShell cannot find `DisplayDimmer.Cli.exe`, make sure Display Dimmer is installed or updated from the Microsoft Store and has been started at least once.

Check the installed command path:

```powershell
(Get-Command DisplayDimmer.Cli.exe -ErrorAction Stop).Source
```

If that command fails, open Display Dimmer > Settings > General > Advanced > Local automation > Manage... and copy a command from the Local automation window.

## Common Commands

```powershell
DisplayDimmer.Cli.exe --list-displays
DisplayDimmer.Cli.exe --set-brightness 40 --target all
DisplayDimmer.Cli.exe --set-brightness 70 --target primary
DisplayDimmer.Cli.exe --set-brightness 55 --target dd_your_stable_id --target dd_your_second_stable_id
DisplayDimmer.Cli.exe --set-brightness 35 --brightness-mode gamma --target dd_your_stable_id
DisplayDimmer.Cli.exe --set-brightness 70 --brightness-mode ddc --target dd_your_stable_id
DisplayDimmer.Cli.exe --set-ddc disabled --target dd_your_stable_id
DisplayDimmer.Cli.exe --adjust-brightness -10 --target dd_your_stable_id
DisplayDimmer.Cli.exe --get-state --target all --pretty
```

Brightness changes are live-only by default. Add `--save` only for scripts that should change saved Display Dimmer settings. `--save` is a settings write, not a cooperative sensor handoff. For a temporary manual dim, record that an active rule was unpaused before the write; only then use `--resume-automation --target <id> --expected-brightness <temporary-level>` to let the rule reassert. The command checks the tracked level, not who made the latest write. It writes no brightness and does not release temperature control. Check the running app's `resume-automation` capability first.

## Temperature And Blue Light Filtering

Use the same Temperature control as the app from your scripts:

```powershell
DisplayDimmer.Cli.exe --set-temperature 4000 --temperature-unit kelvin --target primary --json
DisplayDimmer.Cli.exe --adjust-temperature -200 --temperature-unit kelvin --target primary --json
DisplayDimmer.Cli.exe --set-temperature 0 --target primary --json
DisplayDimmer.Cli.exe --resume-temperature --target primary --json
```

Native temperature ranges from `-100` (warm) through `0` (neutral) to `100` (cool). These are not the UI slider's position values. Add `--temperature-unit kelvin` for integer input from `2500` to `8300` K; lower Kelvin values select warmer colors. Native relative deltas accept `-200..200`; Kelvin deltas accept `-5800..5800`. Absolute values outside the range fail, while relative results clamp to the endpoints.

Kelvin is approximate, not a measured monitor calibration. The app selects the nearest available native tint and returns both the requested Kelvin target and resolved value. Repeated small Kelvin adjustments accumulate within the same intent even when one step does not change the rounded readout. Warm settings reduce blue relative to red; neutral and cool settings are not blue-light-reducing settings.

### Manual Changes, Rules, And Saving

With no source, or `--source cli`, a temperature command is manual control. It masks an active temperature rule without interrupting that rule's brightness. If no temperature owner is active, the temporary value becomes a session baseline beneath later rules, returning when they end. Unrelated settings saves do not persist that temporary value. Another manual/UI/hotkey change, resume, reset, or restart replaces or retires it.

Use `--save` on manual set/adjust only when the new temperature should become the saved baseline:

```powershell
DisplayDimmer.Cli.exe --set-temperature 4000 --temperature-unit kelvin --target primary --save --json
```

`persistenceStatus: "queued"` means the baseline was accepted and saving scheduled, not that disk writing has finished. Temperature save does not save unrelated live brightness/contrast. Named cooperative temperature commands cannot use `--save`; contrast remains live-only and does not accept save or source.

Use plain `--resume-temperature` to release manual temperature interruption and the temporary CLI session baseline. It does not resume brightness or retire a named controller's already-applied tint, even if that controller's standby intent has expired; use named resume to retire the controller. Setting `0` or `6500` K is neutral **control**, not release. The scoped **Resume automation** UI/hotkey action also releases manual temperature intervention.

### Cooperative Temperature Controllers

```powershell
DisplayDimmer.Cli.exe --set-temperature 4000 --temperature-unit kelvin --target dd_your_stable_id --source desk-temperature --json
DisplayDimmer.Cli.exe --update-external-temperature 4000 --temperature-unit kelvin --target dd_your_stable_id --source desk-temperature --json
DisplayDimmer.Cli.exe --resume-temperature --target dd_your_stable_id --source desk-temperature --json
```

A named set/adjust source cooperates: it applies when temperature is unowned, or defers with fresh intent while a temperature rule/manual override controls the display. Per-app temperature outranks schedule temperature. A brightness-only rule does not block external temperature; a rule explicitly set to neutral temperature does.

Refresh-only records standby intent without moving the display or taking visible control. It requires an explicit non-`cli` source name. Refresh within **five seconds** for a later rule release to hand off to the latest value. Expiry removes handoff eligibility, not an already-applied tint: that tint may stay while unowned, but a stale value cannot return after a rule or manual action replaces it.

Named resume retires only that source's current temperature intent/applied value. It cannot clear a newer source or an unrelated manual override. Controllers should release in cleanup, but an abrupt process stop cannot guarantee cleanup runs. External state is cleared on detach/control loss, reset, Pro/temperature access loss, and Local automation shutdown.

Use `temperatureOwner`, `temperatureAutomationInterrupted`, and `externalTemperatureActive` rather than brightness automation flags to decide temperature standby. Inspect `temperatureDisposition` and `effectiveTemperature` in results: success can mean deferred intent rather than a visible change. All targets, including linked groups, return per-physical-display results.

See the [complete temperature contract](cli-api-v1.md#temperature-control-api-11) for feature detection, polling, and source-safe release.

## Advanced Monitor Commands

Display Dimmer also exposes a small advanced DDC/CI VCP command surface for monitor-specific controls. These commands are useful for things like input switching, monitor volume, raw audio mute when supported by the monitor, raw hardware contrast, color presets, color gains, power mode, and display usage time.

Quick rule: use normal brightness, contrast, and temperature commands when you want Display Dimmer's sliders, state, rules, and handoff behavior to stay in sync. Temperature uses the app's gamma color pipeline without changing hardware brightness or DDC preference. It is not a monitor VCP color preset or RGB-gain write. Use VCP commands only when you intentionally want a raw monitor DDC/CI feature.

| Goal | Use | What it changes |
| --- | --- | --- |
| Normal Display Dimmer brightness | `--set-brightness <0-100>` | Updates Display Dimmer's tracked brightness and uses the app's normal DDC/CI-or-gamma brightness route. |
| Force software/gamma brightness | `--set-brightness <0-100> --brightness-mode gamma` | Safely disables DDC/CI at neutral gamma, then applies the requested software/gamma brightness. |
| Force DDC/CI brightness | `--set-brightness <0-100> --brightness-mode ddc` | Enables DDC/CI first, then updates Display Dimmer brightness through the normal DDC-capable path. |
| Normal Display Dimmer contrast | `--set-contrast <0-100>` | Updates Display Dimmer's software/gamma contrast state. It does not change the monitor OSD contrast value. |
| Raw monitor brightness VCP | `--set-vcp 0x10 <value>` | Writes monitor hardware brightness directly. The valid range is monitor-reported, often but not always 0-100. It does not update Display Dimmer brightness state or sliders. |
| Raw monitor contrast VCP | `--set-vcp ddc-contrast <value>` | Writes monitor hardware contrast directly. The valid range is monitor-reported, often but not always 0-100. It does not update Display Dimmer contrast state or sliders. |
| DDC/CI preference | `--set-ddc enabled` / `--set-ddc disabled` | Changes the saved preference; an enabled-to-disabled transition also sets and saves gamma brightness at 100%. |

Normal `--set-brightness` and `--set-contrast` commands use Display Dimmer's app-owned brightness/contrast path. If DDC/CI is enabled and healthy, normal brightness commands can still use DDC internally. If DDC is disabled, unavailable, unreliable, or not appropriate, Display Dimmer can use software/gamma fallback instead. Normal contrast stays on Display Dimmer's software/gamma contrast path.

Use `--brightness-mode gamma` or `--brightness-mode software` with `--set-brightness` when a script should disable DDC/CI first, move through a safe neutral 100% gamma handoff, and then apply the requested brightness. Use `--brightness-mode ddc` when a script should enable DDC/CI first, then set brightness through the normal DDC-capable path:

```powershell
DisplayDimmer.Cli.exe --set-brightness 35 --brightness-mode gamma --target dd_your_stable_id
DisplayDimmer.Cli.exe --set-brightness 35 --brightness-mode ddc --target dd_your_stable_id
```

Use `--set-ddc enabled` or `--set-ddc disabled` when a script needs to change the saved DDC/CI preference. When the preference changes from enabled to disabled, Display Dimmer uses the same safety handoff as Settings: it sets and saves gamma brightness at 100%, preserves gamma contrast, and cancels pending low DDC brightness so the two dimming layers are not stacked accidentally. Repeating `--set-ddc disabled` while DDC/CI is already disabled is a no-op. Enabling DDC/CI reasserts the current Display Dimmer level through the DDC-capable path when display control is enabled. `--set-ddc` saves the preference automatically, without `--save`.

Disabling DDC/CI no longer carries a low hardware brightness percentage into gamma. If a script intentionally needs to dim below normal brightness `0`, it must establish neutral gamma, perform an explicit verified raw VCP `0x10` hardware-brightness write, and then apply software/gamma dimming. This advanced pattern requires Settings > General > **Reset DDC/CI displays to default brightness on exit** to be turned off. See [Automation Recipes](../examples/automation-recipes/README.md#extra-dark-dimming) for cautious values, validation, and restore behavior.

Use VCP commands only when you intentionally want to read or write a raw monitor DDC/CI hardware value:

```powershell
DisplayDimmer.Cli.exe --set-vcp ddc-contrast 50 --target dd_your_stable_id
```

`--set-vcp ddc-contrast` writes hardware VCP `0x12` directly. It does not update Display Dimmer's normal software/gamma contrast slider or saved contrast setting. Use `--set-contrast` when you want Display Dimmer's in-app contrast state to change.

Use `--set-brightness` for normal brightness control. You can still send numeric raw VCP `0x10`, but treat it as an advanced explicit hardware-control escape hatch for diagnostics or the documented extra-dark recipe rather than a named brightness command. `--set-vcp 0x10` writes hardware brightness directly and does not update Display Dimmer's normal brightness slider or saved brightness setting.

Raw DDC/CI VCP commands require the monitor's DDC/CI path to respond, but they do not require Display Dimmer's DDC brightness preference to be enabled. They do not switch the display into DDC brightness mode, do not use software/gamma fallback, do not update Display Dimmer's app-owned brightness/contrast state, and do not participate in automation handoff.

Examples:

```powershell
DisplayDimmer.Cli.exe --list-vcp --target all --pretty
DisplayDimmer.Cli.exe --list-vcp --target dd_your_stable_id --pretty
DisplayDimmer.Cli.exe --get-vcp input-source --target all --pretty
DisplayDimmer.Cli.exe --get-vcp input-source --target dd_your_stable_id --pretty
DisplayDimmer.Cli.exe --set-vcp input-source hdmi1 --target dd_your_stable_id --force
DisplayDimmer.Cli.exe --set-vcp volume 25 --target dd_your_stable_id
DisplayDimmer.Cli.exe --set-vcp volume 25 --target dd_your_stable_id --target dd_your_second_stable_id
DisplayDimmer.Cli.exe --get-vcp usage-time --target dd_your_stable_id --pretty
```

Raw numeric `0x10` is accepted for advanced monitor brightness diagnostics, but it is intentionally not shown in `--list-vcp`. Use `--set-brightness` for normal brightness control.

VCP support and values are monitor-specific. Multi-target `--set-vcp` is allowed only for numeric raw VCP `0x10`, raw DDC contrast, and monitor volume. High-impact writes such as input source, power mode, mute/screen blank, color presets, and RGB gains require `--force` and a target that resolves to exactly one display.

## Targets

Use the `targetId` value from `--list-displays`. When Display Dimmer has a strong stable identity for the display, `targetId` appears as a `dd_...` ID. That is the best value for scripts you plan to keep.

For a uniquely identified physical display, Display Dimmer preserves its `dd_...` target ID across ordinary monitor power cycles and reconnects, including cases where Windows changes `DISPLAYn` or the volatile driver-instance part of the display path. If a reconnect match is ambiguous, Display Dimmer fails closed instead of guessing; rerun `--list-displays` to obtain the current target.

Linked display groups also appear as `dd_...` target IDs when you list displays. Targeting a linked group expands the command to the group's currently connected member displays. Each member still returns its own success or error result.

If `targetId` is `display_1`, `display_2`, or another display number, treat it as session-only. It can change after hotplug, docking, driver updates, or display layout changes, so rerun `--list-displays` before relying on it.

`sessionId` values such as `display_1` are fine for quick tests, but they describe the current Windows display session. They can change after hotplug, docking, driver, or display layout changes.

`primary` is accepted wherever a display target is required. It resolves to the current Windows primary display when the running Display Dimmer app executes the command. It is useful for manual shortcuts, but stable `dd_...` IDs are still preferred for long-running scripts.

Repeat `--target` when a script should affect a specific set of displays. Do not use comma-separated target lists. `--target all` must be used by itself.

## Advanced Integrations

### Override Now Or Cooperate With Automation

Brightness scripts have two useful modes.

By default, `--set-brightness` acts like a manual override. Pass `--source cli` when you want that intent to be explicit in a saved script. Active schedules are interrupted for the targeted displays, active app rules are suspended for the targeted displays, and Display Dimmer will not immediately fight the script.

```powershell
DisplayDimmer.Cli.exe --set-brightness 65 --target dd_your_stable_id --source cli
```

Use `--set-brightness ... --source <name>` when the script is a cooperative external controller such as a light sensor. The source name is just a stable caller label; it does not save settings or grant special access. If no schedule or app rule owns the target, the command can apply immediately. If Display Dimmer automation already owns the target, the command stands down and refreshes the external handoff value instead of interrupting the rule.

For presence or no-motion dimming, prefer manual override mode unless you explicitly want schedules and app rules to win. An empty-room dimmer is usually a user-intent override, not a cooperative brightness handoff.

On occupancy return, a temporary manual dimmer can ask Display Dimmer to release the brightness interruption with API 1.2 `--resume-automation`, provided it recorded an unpaused rule before dimming and the target still has the expected idle level. The level check cannot distinguish a newer user action at that same percentage. A numeric restore is another manual write and does not resume the rule. If the interrupted rule session has already ended, Display Dimmer clears its interruption automatically; a later distinct session can take control. Check the running app's capability; named-source cooperative handoff is the pre-existing alternative only when an active rule is allowed to keep control during the idle period.

```powershell
DisplayDimmer.Cli.exe --set-brightness 65 --target dd_your_stable_id --source desk-light-sensor
```

Use `--update-external-brightness` with the same named source when Display Dimmer automation is already in control and your sensor or bridge is standing by:

```powershell
DisplayDimmer.Cli.exe --update-external-brightness 65 --target dd_your_stable_id --source desk-light-sensor
```

`--update-external-brightness` refreshes the desired external value without moving the monitor and without interrupting schedules or app rules. When the schedule or app rule ends, Display Dimmer can hand off to the fresh external value instead of briefly restoring a stale manual value first.

For scripts that manage multiple displays, decide per display. Use `--set-brightness ... --source <name>` for displays that are not owned by Display Dimmer automation, and use `--update-external-brightness` for displays where a schedule or app rule is currently in control. Use `--source cli` when the script is intentionally supposed to override Display Dimmer automation, such as a manual shortcut or no-motion dimmer.

## Watch State Changes

Use:

```powershell
DisplayDimmer.Cli.exe --watch --json
```

The watch command emits JSON Lines: one JSON object per line. Parse each line separately.

It emits an initial `snapshot`, then emits `stateChanged` when Display Dimmer's cached display or automation state changes.

Simple PowerShell watcher:

```powershell
DisplayDimmer.Cli.exe --watch --json | ForEach-Object {
    $event = $_ | ConvertFrom-Json

    if ($event.event -eq "stateChanged") {
        foreach ($display in $event.state.displays) {
            "$($display.name): brightness=$($display.brightness), automationInterrupted=$($display.automationInterrupted)"
        }
    }
}
```

For **brightness** cooperative sensor-style integrations, stand by when a display has an uninterrupted app rule or schedule:

```powershell
$perAppOwns = $display.perAppActive -and -not $display.perAppInterrupted
$scheduleOwns = $display.scheduleActive -and -not $display.scheduleInterrupted
```

Make that decision per display when controlling more than one monitor. If display 2 is owned by a fullscreen app rule or schedule, send `--update-external-brightness` for display 2 and continue using `--set-brightness ... --source <name>` for displays that are not owned by Display Dimmer automation. Use `--source cli` when the script is intentionally supposed to override Display Dimmer automation, such as a manual shortcut or no-motion dimmer.

For temperature, use `temperatureOwner` (`manual`, `perApp`, `schedule`, `external`, `session`, or `saved`) and `temperatureAvailable` independently. Temperature fields are nullable/absent on older apps. Watch reports meaningful value, owner, availability, and freshness changes, not controller heartbeat timestamps.

The stream is local-only and requires Display Dimmer to be running. It reports the state Display Dimmer is already tracking, not a fresh hardware readback from DDC/CI or gamma. Use `dd_...` target IDs when your script later sends commands you plan to keep.

## Troubleshooting Quick Checks

If a command does not do what you expected, start with JSON output:

```powershell
DisplayDimmer.Cli.exe --set-brightness 45 --target dd_your_stable_id --source cli --json --pretty
```

Check these fields first:

- `success`: whether the overall command succeeded.
- `partial`: whether some targets worked and some failed.
- `exitCode`: script-friendly result code.
- `errorCode`: stable error name for scripts.
- `message`: human-readable summary.
- `results`: per-display success, target, mode, value, and error details.

Common cases:

- `appUnavailable`: Display Dimmer is not running, Local automation is off, Pro is locked, or the command is running as a different Windows user/session.
- `targetNotFound`: run `--list-displays` again and copy the current `targetId`. Recheck after docking, hotplug, driver updates, or display layout changes.
- `partial=true` with `errorCode=partialSuccess`: inspect every item in `results`. One display or linked group member can fail while another succeeds.
- Command succeeds but a schedule or app rule still controls brightness: a named `--source <name>` may have cooperated with Display Dimmer automation and refreshed the handoff value instead of interrupting the rule. Use `--source cli` only when you intentionally want a manual override.
- Task Scheduler command cannot reach Display Dimmer: run the task as the same Windows user and use "Run only when user is logged on".
- VCP command fails: VCP commands need the target monitor's DDC/CI path to respond, but they do not require Display Dimmer's DDC brightness preference to be enabled. `--force` allows high-impact writes, but it does not override disconnected displays, unsupported features, DDC/CI timeouts, or monitor read/write failures.
- Watch command seems quiet: `--watch --json` emits an initial snapshot, then only emits when Display Dimmer's tracked state changes.

## Security

Local automation is a Pro feature. It is opt-in, local-only, and can be turned off from the same Local automation window. It does not open a network port.

The app uses a current-user named pipe with an explicit Windows ACL. Other Windows accounts are not granted access. Any process running in your Windows account can still send commands, so this is a local automation feature, not a security boundary between programs in the same account.

For app privacy information, see [Display Dimmer privacy](https://displaydimmer.com/privacy). For help with setup or monitor compatibility, see [Display Dimmer support](https://displaydimmer.com/support).

## Examples

See:

- [Automation recipes](../examples/automation-recipes)
- [C# client](../examples/csharp-client)
- [Task Scheduler](../examples/task-scheduler)
- [AutoHotkey shortcuts](../examples/autohotkey)
- [Stream Deck and macro buttons](../examples/stream-deck)
- [Arduino light sensor](../examples/arduino-light-sensor)
- [Arduino motion sensor](../examples/arduino-motion-sensor)

Full technical reference: [CLI/API 1.2 reference (wire protocol 1)](cli-api-v1.md).
