# Windows Inactivity Dimmer

Dim eligible screens after five minutes without keyboard or mouse input. When you return, the watcher resumes an automation rule that was active before idle; otherwise it restores each screen's captured brightness. The default idle level is 20%. The watcher uses Display Dimmer's [Local automation CLI](../../docs/local-automation-api.md); it does not set the DDC/CI preference or save a new brightness baseline.

With a running Display Dimmer 2.2.10 app, the watcher dims and restores displays that remain without an active rule throughout the idle cycle; it skips automation-owned displays. Dimming through an active rule and resuming it requires a running 2.2.11 or later app advertising `resume-automation`.

This example has two scripts:

| Script | Purpose |
|---|---|
| [`Start-WindowsInactivityDimmer.ps1`](Start-WindowsInactivityDimmer.ps1) | Run the watcher manually or from Task Scheduler. |
| [`Install-WindowsInactivityDimmerTask.ps1`](Install-WindowsInactivityDimmerTask.ps1) | Create an **at log on** task for the current Windows user. Running this installer is optional. |

## Before You Start

1. Start Display Dimmer. For automatic sign-in startup, enable its **Start with Windows** setting.
2. Unlock Pro and enable **Settings > General > Advanced > Local automation > Manage...**.
3. In PowerShell, verify that `DisplayDimmer.Cli.exe --get-state --target all --json` succeeds. Automatic schedule/app-rule resume needs a running app whose response lists `resume-automation` in `capabilities`; older builds are skipped when an active rule owns the display. If the command is unavailable, use `-CliPath "C:\path\to\DisplayDimmer.Cli.exe"` with the scripts below.
4. Keep these example files in a permanent folder if you create a scheduled task. The task runs the script from that exact path.

The watcher and Display Dimmer must run in the **same interactive Windows user session**. It waits and retries on an idle check if Display Dimmer has not finished starting yet.

## Try It Manually

In PowerShell, set `$example` to the folder containing these two scripts:

```powershell
$example = "C:\path\to\display-dimmer-local-automation\examples\windows-inactivity-dimmer"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$example\Start-WindowsInactivityDimmer.ps1" -IdleSeconds 10 -DryRun
```

Leave the mouse and keyboard alone for ten seconds. `-DryRun` prints the displays that *would* dim without changing brightness. Press Ctrl+C to stop. Then, when you are ready to test live control:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$example\Start-WindowsInactivityDimmer.ps1" -IdleSeconds 10 -DimBrightness 20
```

Move the mouse to check that automation resumes where it was active, and other unchanged displays return to their previous levels. For normal use, omit `-IdleSeconds`:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$example\Start-WindowsInactivityDimmer.ps1" -IdleMinutes 5 -DimBrightness 20
```

Change settings with parameters; you do not need to edit the script:

| Parameter | Default | Effect |
|---|---:|---|
| `-IdleMinutes` | `5` | Minutes without keyboard or mouse input before dimming. |
| `-DimBrightness` | `20` | Idle brightness percentage, from 0 to 100. Screens already at or below it stay unchanged. `-SetBrightness` is accepted as an alias. |
| `-PollSeconds` | `1` | Interval between input checks, from 1 to 60 seconds. |
| `-IdleSeconds` | off | Overrides `-IdleMinutes` for a short supervised test. |
| `-DryRun` | off | Reads state and prints intended dimming, without brightness writes. |
| `-CliPath` | app execution alias | Exact path to a different `DisplayDimmer.Cli.exe`. |

## Start Automatically With Windows

After the manual test, run the installer once. It creates a task that starts the watcher 30 seconds after you sign in:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$example\Install-WindowsInactivityDimmerTask.ps1"
```

Add `-WhatIf` to preview the planned task without registering it, or `-RunNow` to start it immediately. The task uses your interactive Windows session. Leave its PowerShell window visible for the first test; later, rerun the installer with `-Hidden -Force` if you want it hidden.

To change the five-minute timeout or 20% level, run the installer again with new values and `-Force`:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$example\Install-WindowsInactivityDimmerTask.ps1" -IdleMinutes 8 -DimBrightness 15 -Force
```

The new settings take effect at the next sign-in. You can inspect, run, end, disable, or delete **Display Dimmer Inactivity Example** in Task Scheduler. Before ending a running task, move the mouse and confirm that your screens have restored. Ending it can skip the watcher's best-effort restore.

## Manual Task Scheduler Setup

If you prefer the Windows UI, create a task in **Task Scheduler > Create Task** with these settings:

| Tab | Setting |
|---|---|
| General | Use your Windows account. Select **Run only when user is logged on**; leave **Run with highest privileges** off. |
| Triggers | **At log on** for your account; optionally delay for 30 seconds. |
| Actions | Start `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`. Arguments: `-NoProfile -ExecutionPolicy Bypass -File "C:\path\to\Start-WindowsInactivityDimmer.ps1" -IdleMinutes 5 -DimBrightness 20`. |
| Conditions | Allow the task to start and continue on battery power if you use a laptop. |
| Settings | If already running, **Do not start a new instance**. Disable the default **Stop the task if it runs longer than 3 days** limit. Optionally restart on failure every minute, up to three times. |

Keep it in the interactive user session. **Run whether user is logged on or not** is unsuitable for this watcher.

## Restore Behavior

Each connected, controllable physical display above the requested idle level is dimmed separately. A display that is disconnected, disabled, no longer identifiable, or changed to another brightness while idle is left alone. The script checks Display Dimmer's reported state, not physical monitor readback. New screens are considered on the next idle cycle.

Idle dimming uses `--source cli` to temporarily interrupt an active schedule or app rule. On activity, the watcher calls scoped `--resume-automation` only for displays whose automation was active and not interrupted before idle. It leaves a pre-existing pause alone. If the rule ended while you were away, it falls back to the captured brightness after checking that the display is still at the idle level. The CLI's older named-source cooperative handoff already works in 2.2.10, but stands down while a rule owns brightness; it cannot dim during that rule or release a manual `--source cli` interruption. A running app without the new `resume-automation` capability will therefore not dim automation-owned displays, rather than leave their rules interrupted.

The watcher skips a display if one rule owns it while another is already interrupted. If a new rule appears while idle, it will not overwrite that rule with the captured brightness; check the level in Display Dimmer if the idle level remains.

The watcher never passes `--save`. Ctrl+C makes one best-effort restore attempt, but a forced stop, Windows shutdown, app failure, or CLI timeout can leave a screen at the last reported level. Recover it with Display Dimmer's controls. A hardware or driver failure can also prevent the requested level from taking effect even when the CLI reports success.
