# Display Dimmer Local Automation

Documentation for using Display Dimmer from local scripts, shortcuts, Task Scheduler, sensor projects, macro tools, and helper apps.

Display Dimmer Local Automation lets the running Display Dimmer app receive brightness, contrast, temperature, state, and advanced monitor-control commands from the installed `DisplayDimmer.Cli.exe` command-line tool. Scripts do not talk to monitors directly; Display Dimmer keeps ownership of display identity, DDC/CI safety checks, software fallback, schedules, app rules, and automation handoff.

Display Dimmer 2.2.10 introduced temperature control in API **1.1**, including approximate Kelvin input and cooperative blue light filter automation. The wire protocol remains `apiVersion: 1`; `--api-version` still prints `1`. Check the running app's `apiRevision` and `capabilities` in JSON before using temperature commands. Older apps do not advertise these capabilities.

Display Dimmer 2.2.11 introduced conditional brightness automation resume in API **1.2**. Display Dimmer 2.2.12 retained that command and added saved preset listing (`list-presets`) and recall (`presets`) to the same API revision. Check the running app's relevant capability before using those features. A newer preset already contains its display targets; older presets need one explicit `--target` at recall time.

Display Dimmer 2.2.12 retains wire API **1** and revision **1.2**. The running app advertises `temperature`, `temperature-kelvin`, `external-temperature`, `presets`, `list-presets`, and `resume-automation`; check the relevant capability, not just `--api-version`.

## Unattended Pro activation for IT

Display Dimmer 2.2.12+ also accepts a standalone Lemon Squeezy activation command. Run `DisplayDimmer.Cli.exe --activate-license --license-key-stdin --silent` in the intended Windows user context and supply the key through redirected stdin from your deployment secret store. Activation works while the app is Free and does not require a running app or Local automation. Restart an already-running app afterward. This is per-user licensing, not machine-wide activation or a wire API command. See [IT deployment](docs/it-license-deployment.md) for safe repeat deployment, account scope, exit codes and fleet rate staggering.

## Requirements

- Display Dimmer installed from the Microsoft Store.
- Display Dimmer running in the current Windows user session.
- Display Dimmer Pro unlocked.
- Local automation enabled in Display Dimmer:
  Settings > General > Advanced > Local automation > Manage...
- PowerShell, Command Prompt, Task Scheduler, or another local tool that can run `DisplayDimmer.Cli.exe`.

Local automation is designed for same-user local control. It is not a remote-control API and is not intended to expose Display Dimmer over a network.

## Quick Start

List displays:

```powershell
DisplayDimmer.Cli.exe --list-displays
```

Set the primary display to 40% brightness:

```powershell
DisplayDimmer.Cli.exe --set-brightness 40 --target primary
```

Read current state as JSON:

```powershell
DisplayDimmer.Cli.exe --get-state --target all --json --pretty
```

Watch for state changes:

```powershell
DisplayDimmer.Cli.exe --watch --json
```

## Which Command Should I Use?

| Goal | Command pattern |
| --- | --- |
| Find target IDs | `--list-displays` |
| Set brightness now | `--set-brightness <0-100> --target <target>` |
| Adjust brightness up/down | `--adjust-brightness <-100..100> --target <target>` |
| Save brightness as the Display Dimmer setting | `--set-brightness <0-100> --target <target> --save` |
| List saved preset names and stable IDs | `--list-presets --json`; saved Settings presets only |
| Recall a saved preset | `--apply-preset <name-or-id>` for a preset with saved displays; add `--target <target>` only for an older preset without saved displays |
| Override schedules/app rules | `--set-brightness <0-100> --target <target> --source cli` |
| Request brightness automation resume after your temporary override | `--resume-automation --target <target> --expected-brightness <0-100>`; use only when you recorded a previously unpaused rule |
| Cooperate with schedules/app rules | `--set-brightness <0-100> --target <target> --source <name>` |
| Keep a sensor handoff value fresh without moving the display | `--update-external-brightness <0-100> --target <target> --source <name>` |
| Set warmer screen colors | `--set-temperature 4000 --temperature-unit kelvin --target <target>` |
| Adjust warmth | `--adjust-temperature -200 --temperature-unit kelvin --target <target>` |
| Save manual temperature | `--set-temperature -50 --target <target> --save` |
| Release manual temperature control | `--resume-temperature --target <target>` |
| Refresh a cooperative temperature handoff | `--update-external-temperature 4000 --temperature-unit kelvin --target <target> --source <name>` |
| Read state for a script | `--get-state --target <target> --json` |
| Watch state changes | `--watch --json` |
| Force software/gamma brightness route | `--set-brightness <0-100> --brightness-mode gamma --target <target>` |
| Force DDC/CI brightness route | `--set-brightness <0-100> --brightness-mode ddc --target <target>` |
| Change saved DDC/CI preference | `--set-ddc enabled\|disabled --target <target>` |
| Raw monitor DDC/CI features | `--get-vcp` / `--set-vcp` |

## Display Targets

Use `--list-displays` to find each physical display or linked display group's `targetId`.

Recommended target forms:

- `primary` for the current Windows primary display.
- `all` for all currently connected displays. Check per-display results because a display can still fail if control is disabled, DDC/CI is unavailable, or the monitor rejects a command.
- `dd_...` stable Display Dimmer IDs for physical displays or linked display groups in scripts you plan to keep.
- `display_1`, `display_2`, etc. only for quick session tests.

For a uniquely identified physical display, Display Dimmer preserves its `dd_...` target ID across ordinary monitor power cycles and reconnects, including cases where Windows changes `DISPLAYn` or the volatile driver-instance part of the display path. If a reconnect match is ambiguous, Display Dimmer fails closed instead of guessing; rerun `--list-displays` to obtain the current target.

If a display only has a `display_N` target, treat it as session-only and rerun `--list-displays` after docking, hotplug, GPU driver changes, or display layout changes. Linked group target IDs are also stable `dd_...` IDs and expand to the group's currently connected members with display control enabled. Each selected member returns its own success or error result; disconnected members and members with display control disabled are omitted.

## Documentation

- [Local Automation Guide](docs/local-automation-api.md)
- [CLI/API 1.2 Reference (wire protocol 1)](docs/cli-api-v1.md)
- [Examples](examples/README.md)
- [Unattended Pro activation for IT](docs/it-license-deployment.md)
- [Managed Microsoft Store updates](docs/managed-store-updates.md)

Start with the Local Automation Guide if you want setup steps and common commands. Use the examples when you want copyable patterns for PowerShell, Task Scheduler, AutoHotkey, Stream Deck, sensor bridges, or C# clients. Use the CLI/API reference when you need exact commands, JSON fields, exit codes, VCP behavior, or scripting details.

Useful example entry points:

- [Windows inactivity dimmer](examples/windows-inactivity-dimmer/)
- [Automation recipes](examples/automation-recipes/)
- [C# client](examples/csharp-client/)
- [Task Scheduler](examples/task-scheduler/)
- [AutoHotkey shortcuts](examples/autohotkey/)
- [Stream Deck and macro buttons](examples/stream-deck/)
- [Arduino light sensor](examples/arduino-light-sensor/)
- [Arduino motion sensor](examples/arduino-motion-sensor/)

## Saved Presets (2.2.12)

Save a preset in Settings > Presets, then check the running app's `list-presets`
and `presets` capabilities before listing or recalling it:

```powershell
DisplayDimmer.Cli.exe --list-presets --json
DisplayDimmer.Cli.exe --apply-preset "Evening" --json
DisplayDimmer.Cli.exe --get-state --target all --json
```

Use the preset's stable ID from the list in a durable script. New presets carry
their saved display targets; do not add `--target` to their recall command.
Only older presets without saved displays need exactly one target expression.
The response reports `requiresTarget` for each saved preset. There is no separate
`--get-preset` command. Recall leaves levels not included in the preset unchanged
and uses the app's normal manual preset behavior; it does not edit the preset
or verify that a hardware write has finished. See the
[preset reference](docs/cli-api-v1.md#saved-preset-recall-api-12).

## Common Commands

Set brightness:

```powershell
DisplayDimmer.Cli.exe --set-brightness 35 --target dd_your_display_id
```

Set brightness through software/gamma, disabling DDC/CI first:

```powershell
DisplayDimmer.Cli.exe --set-brightness 35 --brightness-mode gamma --target dd_your_display_id
```

Set brightness through DDC/CI, enabling DDC/CI first:

```powershell
DisplayDimmer.Cli.exe --set-brightness 70 --brightness-mode ddc --target dd_your_display_id
```

Enable or disable DDC/CI for a display:

```powershell
DisplayDimmer.Cli.exe --set-ddc disabled --target dd_your_display_id
DisplayDimmer.Cli.exe --set-ddc enabled --target dd_your_display_id
```

Adjust brightness:

```powershell
DisplayDimmer.Cli.exe --adjust-brightness -10 --target primary
```

Set contrast:

```powershell
DisplayDimmer.Cli.exe --set-contrast 60 --target dd_your_display_id
```

Choose whether a script should override Display Dimmer automation or cooperate with it:

```powershell
DisplayDimmer.Cli.exe --set-brightness 45 --target primary --source cli
DisplayDimmer.Cli.exe --update-external-brightness 45 --target primary --source desk-light-sensor
```

By default, `--set-brightness` acts like a manual override. Pass `--source cli` when you want that intent to be explicit in a saved script. This interrupts active schedules/app rules for the target so Display Dimmer does not immediately fight the script.

If a script temporarily overrides an active rule, record that the rule was unpaused before the write. When the temporary level is no longer needed, API 1.2 `--resume-automation --target <stable-id> --expected-brightness <temporary-level>` can release that brightness interruption without restoring a stale number; check the running app's `resume-automation` capability first. The expected level detects a different later percentage, but cannot identify a newer user action at the same percentage. The named-source cooperative handoff below already existed in 2.2.10 and does not dim through an active rule.

Automation resume also releases manual contrast holds on the targeted schedule/app rules. The expected-brightness check does not compare contrast, so do not use this command when an existing manual contrast intervention must remain in place. Temperature intervention has its own `--resume-temperature` command.

For each display, one selected app rule supplies its included brightness, contrast, and temperature levels. A schedule can supply levels that app rule leaves unchanged; another matching app rule cannot fill those omitted levels. App rules take priority over schedules for levels they include. Preset-linked rules use the preset's saved display targets and levels, not unapplied Presets edits.

Use a named source such as `desk-light-sensor` for cooperative sensor integrations. With `--save` omitted, a named brightness source applies when no schedule or app rule owns brightness on the target. Otherwise it stands down and refreshes the external handoff value instead of interrupting the rule. Contrast-only and temperature-only rules leave brightness available and keep running. Adding `--save` to a named brightness request uses manual/saved override behavior instead.

Use `--update-external-brightness` when the script is already standing by and should only keep its desired handoff value fresh. Pass the same named `--source` you use for cooperative sensor commands. This command does not move the display and does not interrupt schedules or app rules.

Use JSON for scripts:

```powershell
DisplayDimmer.Cli.exe --set-brightness 40 --target primary --json --pretty
```

## Temperature And Blue Light Filtering

Use the app's Temperature control from scripts without changing brightness or contrast:

```powershell
DisplayDimmer.Cli.exe --set-temperature 4000 --temperature-unit kelvin --target primary
DisplayDimmer.Cli.exe --adjust-temperature -200 --temperature-unit kelvin --target primary
DisplayDimmer.Cli.exe --set-temperature 0 --target primary
DisplayDimmer.Cli.exe --resume-temperature --target primary
```

Native units range from `-100` (warm) through `0` (neutral) to `100` (cool). Kelvin input ranges from `2500` to `8300`; lower values are warmer. Kelvin readouts are approximate, not calibrated monitor measurements. Warm settings reduce blue relative to red; neutral and cool settings are not blue-light-reducing settings.

Temperature changes are temporary by default and remain a session baseline underneath later rules. They cannot be saved accidentally by an unrelated settings change. Use `--save` on manual set/adjust commands to change the saved temperature. A response with `persistenceStatus: "queued"` means saving was scheduled, not that disk persistence or visible hardware application has completed. Contrast remains live-only and does not accept `--save`.

Omitting `--source`, or using `--source cli`, is a manual **temperature-only** override. It leaves rule-driven brightness running. A named source cooperates with temperature-enabled schedules and app rules; a brightness-only rule does not block it. Use `--update-external-temperature` to refresh standby intent without moving the display. Named cooperative sources cannot use `--save`.

External temperature intent stays eligible for handoff for five seconds. An already-applied tint does not disappear just because the controller stops, but a stale tint cannot return after a rule or manual action replaces it. Use `--resume-temperature --source <name>` to retire that source explicitly. Plain `--resume-temperature` releases manual temperature intervention; setting neutral does not release ownership.

See the [temperature reference](docs/cli-api-v1.md#temperature-control-api-11) for source-safe release, state inspection, and error handling.

## DDC/CI, Gamma, And VCP

Normal `--set-brightness` uses Display Dimmer's normal brightness path for each display: DDC/CI when enabled and healthy, or software/gamma when DDC/CI is disabled, unavailable, or unreliable. Use `--brightness-mode gamma` or `--brightness-mode software` when a script should disable DDC/CI first, move through a safe neutral 100% gamma handoff, and then set the requested software/gamma brightness. Use `--brightness-mode ddc` when a script should enable DDC/CI first, then set brightness through Display Dimmer's normal DDC-capable path.

Use `--set-ddc enabled` or `--set-ddc disabled` when a script needs to change the saved DDC/CI preference. When the preference changes from enabled to disabled, Display Dimmer sets and saves gamma brightness at a neutral 100% while preserving gamma contrast, preventing accidental double dimming over low monitor hardware brightness. Repeating `--set-ddc disabled` while DDC/CI is already disabled is a no-op. Enabling DDC/CI starts a background brightness read so Display Dimmer can adopt the monitor's current hardware level instead of immediately writing the software-dimming level to it. The command reply can arrive before this handoff completes, and newer brightness requests take precedence. `--set-ddc` saves the preference automatically, without `--save`.

For normal scripts, prefer one `--set-brightness` command. Disabling DDC/CI no longer carries a low hardware brightness percentage into gamma. An extra-dark script must opt into both layers explicitly: establish neutral gamma, write raw monitor brightness after checking VCP `0x10`, and then request software/gamma dimming:

```powershell
DisplayDimmer.Cli.exe --set-brightness 100 --brightness-mode gamma --target dd_your_display_id --source cli --json
DisplayDimmer.Cli.exe --set-vcp 0x10 10 --target dd_your_display_id --verify --json
DisplayDimmer.Cli.exe --set-brightness 20 --brightness-mode gamma --target dd_your_display_id --source cli --json
```

Raw VCP `0x10` values are monitor-specific and are not necessarily percentages; read the monitor's current value and `vcpMax` first. This pattern also requires Settings > General > **Reset DDC/CI displays to default brightness on exit** to be turned off. For the full extra-dark recipe, including cautious values, error checking, and exact restore behavior, see [Automation Recipes](examples/automation-recipes/README.md#extra-dark-dimming).

Display Dimmer also includes advanced VCP commands for monitors that support DDC/CI features such as input source, volume, mute, raw monitor contrast, and selected color controls.

VCP behavior is monitor-specific. Some displays ignore commands, report incomplete capabilities, or become temporarily unavailable during HDR, sleep, resume, docking, or input changes. Prefer normal brightness, contrast, and temperature commands unless you specifically need raw monitor controls.

App temperature uses Display Dimmer's existing software/gamma color pipeline. It does not change monitor VCP color presets or RGB gains, hardware brightness, or the saved DDC/CI preference.

See [CLI/API 1.2 Reference](docs/cli-api-v1.md) for supported VCP names, force requirements, safety limits, and JSON result fields.

## Exit Codes

Scripts should use the CLI exit code and JSON response together.

Common display-control exit codes (standalone activation has [its own outcomes](docs/it-license-deployment.md#exit-codes-and-safe-repeat-deployment)):

| Code | Meaning |
|---:|---|
| `0` | Success |
| `1` | Invalid arguments |
| `2` | Display Dimmer app or Local automation unavailable |
| `3` | Target not found |
| `4` | Unsupported command or operation |
| `5` | Operation failed |
| `6` | Partial success |
| `7` | Local automation timeout |

## Security And Privacy

Local automation is local-only and scoped to the current Windows user. For display control, the CLI talks to the running Display Dimmer app on the same machine. It does not create a network listener.

The public target to copy for scripts is `targetId`. JSON may include diagnostic fields such as raw display identity or Windows device name for troubleshooting, but those are not stable public script targets.

## Support

Display Dimmer support:

- Website: https://displaydimmer.com
- Support: https://displaydimmer.com/support
- Privacy: https://displaydimmer.com/privacy
- Email: support@displaydimmer.com

When reporting automation issues, include the command you ran (redact any license key), the exit code, whether `--json` returned an error code, and whether Display Dimmer was running with Local automation enabled.
