# Display Dimmer Local Automation

Documentation for using Display Dimmer from local scripts, shortcuts, Task Scheduler, sensor projects, macro tools, and helper apps.

Display Dimmer Local Automation lets the running Display Dimmer app receive brightness, contrast, state, and advanced monitor-control commands from the installed `DisplayDimmer.Cli.exe` command-line tool. Scripts do not talk to monitors directly; Display Dimmer keeps ownership of display identity, DDC/CI safety checks, software fallback, schedules, app rules, and automation handoff.

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
| Override schedules/app rules | `--set-brightness <0-100> --target <target> --source cli` |
| Cooperate with schedules/app rules | `--set-brightness <0-100> --target <target> --source <name>` |
| Keep a sensor handoff value fresh without moving the display | `--update-external-brightness <0-100> --target <target> --source <name>` |
| Read state for a script | `--get-state --target <target> --json` |
| Watch state changes | `--watch --json` |
| Force software/gamma brightness route | `--set-brightness <0-100> --brightness-mode gamma --target <target>` |
| Force DDC/CI brightness route | `--set-brightness <0-100> --brightness-mode ddc --target <target>` |
| Change saved DDC/CI preference only | `--set-ddc enabled|disabled --target <target>` |
| Raw monitor DDC/CI features | `--get-vcp` / `--set-vcp` |

## Display Targets

Use `--list-displays` to find each physical display or linked display group's `targetId`.

Recommended target forms:

- `primary` for the current Windows primary display.
- `all` for all currently connected displays. Check per-display results because a display can still fail if control is disabled, DDC/CI is unavailable, or the monitor rejects a command.
- `dd_...` stable Display Dimmer IDs for physical displays or linked display groups in scripts you plan to keep.
- `display_1`, `display_2`, etc. only for quick session tests.

If a display only has a `display_N` target, treat it as session-only and rerun `--list-displays` after docking, hotplug, GPU driver changes, or display layout changes. Linked group target IDs are also stable `dd_...` IDs and expand to the group's currently connected member displays. Each member still returns its own success or error result.

## Documentation

- [Local Automation Guide](docs/local-automation-api.md)
- [CLI/API v1 Reference](docs/cli-api-v1.md)
- [Examples](examples/README.md)

Start with the Local Automation Guide if you want setup steps and common commands. Use the examples when you want copyable patterns for PowerShell, Task Scheduler, AutoHotkey, Stream Deck, sensor bridges, or C# clients. Use the CLI/API reference when you need exact commands, JSON fields, exit codes, VCP behavior, or scripting details.

Useful example entry points:

- [Automation recipes](examples/automation-recipes/)
- [C# client](examples/csharp-client/)
- [Task Scheduler](examples/task-scheduler/)
- [AutoHotkey shortcuts](examples/autohotkey/)
- [Stream Deck and macro buttons](examples/stream-deck/)
- [Arduino light sensor](examples/arduino-light-sensor/)
- [Arduino motion sensor](examples/arduino-motion-sensor/)

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

Use a named source such as `desk-light-sensor` for cooperative sensor integrations. Named-source `--set-brightness` applies immediately when no schedule or app rule owns the target. If Display Dimmer automation already owns that display, the command stands down and refreshes the external handoff value instead of interrupting the rule.

Use `--update-external-brightness` when the script is already standing by and should only keep its desired handoff value fresh. Pass the same named `--source` you use for cooperative sensor commands. This command does not move the display and does not interrupt schedules or app rules.

Use JSON for scripts:

```powershell
DisplayDimmer.Cli.exe --set-brightness 40 --target primary --json --pretty
```

## DDC/CI, Gamma, And VCP

Normal `--set-brightness` uses Display Dimmer's normal brightness path for each display: DDC/CI when enabled and healthy, or software/gamma when DDC/CI is disabled, unavailable, or unreliable. Use `--brightness-mode gamma` or `--brightness-mode software` when a script should disable DDC/CI first, transition the current level to software/gamma, and then set brightness. Use `--brightness-mode ddc` when a script should enable DDC/CI first, then set brightness through Display Dimmer's normal DDC-capable path.

Use `--set-ddc enabled` or `--set-ddc disabled` when a script only needs to change the saved DDC/CI preference. Disabling DDC/CI uses Display Dimmer's normal DDC-off-to-gamma transition. Enabling DDC/CI reasserts the current Display Dimmer level through the DDC-capable path when display control is enabled. `--set-ddc` saves the preference automatically, without `--save`.

For normal scripts, prefer one `--set-brightness` command. If you intentionally want to dim lower than Display Dimmer's normal brightness range, set the DDC brightness first, then switch DDC/CI off at the same low level:

```powershell
DisplayDimmer.Cli.exe --set-brightness 0 --brightness-mode ddc --target dd_your_display_id --source cli --json
DisplayDimmer.Cli.exe --set-ddc disabled --target dd_your_display_id --json
```

This pattern requires Settings > General > **Reset DDC/CI displays to default brightness on exit** to be turned off. If that setting is on, disabling DDC/CI can restore monitor hardware brightness to 100 and prevent the DDC + gamma stack from working. For the full extra-dark recipe, including DDC/CI support and restore behavior, see [Automation Recipes](examples/automation-recipes/README.md#extra-dark-dimming).

Display Dimmer also includes advanced VCP commands for monitors that support DDC/CI features such as input source, volume, mute, raw monitor contrast, and selected color controls.

VCP behavior is monitor-specific. Some displays ignore commands, report incomplete capabilities, or become temporarily unavailable during HDR, sleep, resume, docking, or input changes. Prefer normal brightness and contrast commands unless you specifically need raw monitor controls.

See [CLI/API v1 Reference](docs/cli-api-v1.md) for supported VCP names, force requirements, safety limits, and JSON result fields.

## Exit Codes

Scripts should use the CLI exit code and JSON response together.

Common exit codes:

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

Local automation is local-only and scoped to the current Windows user. The CLI talks to the running Display Dimmer app on the same machine. It does not create a network listener.

The public target to copy for scripts is `targetId`. JSON may include diagnostic fields such as raw display identity or Windows device name for troubleshooting, but those are not stable public script targets.

## Support

Display Dimmer support:

- Website: https://displaydimmer.com
- Support: https://displaydimmer.com/support
- Privacy: https://displaydimmer.com/privacy
- Email: support@displaydimmer.com

When reporting automation issues, include the command you ran, the exit code, whether `--json` returned an error code, and whether Display Dimmer was running with Local automation enabled.
