# Task Scheduler Example

This example creates a Windows Task Scheduler task that calls `DisplayDimmer.Cli.exe`.

It does not create a Display Dimmer schedule in the Display Dimmer UI. Windows owns the schedule. Display Dimmer only receives the CLI command when Windows runs the task.

This is useful for automation outside Display Dimmer's built-in scheduler:

- a login task
- a one-off local workflow
- a task managed by another tool
- a Windows schedule that calls Display Dimmer directly

## Requirements

- Install or update Display Dimmer from the Microsoft Store.
- Local automation requires Display Dimmer Pro.
- Display Dimmer must already be running when the task fires.
- Local automation must be turned on in Settings > General > Advanced > Local automation > Manage...
- The task must run as the same Windows user who is running Display Dimmer.
- Use "Run only when user is logged on".
- Do not use service/session 0 tasks for display control.
- The installed `DisplayDimmer.Cli.exe` command must be available in PowerShell.
- Use a `targetId` from `--list-displays`. Prefer a `dd_...` target ID, not `display_1`, for tasks you plan to keep.

## Get A Target ID

Start Display Dimmer from the Start menu or tray, then run:

```powershell
DisplayDimmer.Cli.exe --list-displays
```

Copy the `targetId` for the display you want. Prefer a `dd_...` value for a task you plan to keep.

Example placeholder:

```text
dd_your_stable_id
```

Do not copy this placeholder. Use the value from your machine.

## Create A Daily Task

Create or replace a daily task:

```powershell
powershell -ExecutionPolicy Bypass -File ".\examples\task-scheduler\Create-DisplayDimmerBrightnessTask.ps1" `
  -Target dd_your_stable_id `
  -Brightness 40 `
  -At "19:00"
```

The script validates the selected display before registering the task. If the target ID is wrong, it fails before creating a broken task.

## Preview Only

Add `-WhatIf` to print what would be registered without creating the task:

```powershell
powershell -ExecutionPolicy Bypass -File ".\examples\task-scheduler\Create-DisplayDimmerBrightnessTask.ps1" `
  -Target dd_your_stable_id `
  -Brightness 40 `
  -At "19:00" `
  -WhatIf
```

## Run Immediately

Add `-RunNow` to register the task and immediately test that Windows can launch it:

```powershell
powershell -ExecutionPolicy Bypass -File ".\examples\task-scheduler\Create-DisplayDimmerBrightnessTask.ps1" `
  -Target dd_your_stable_id `
  -Brightness 40 `
  -At "19:00" `
  -RunNow
```

Important: `-RunNow` ignores the scheduled time for the immediate test run. The task is still registered for the daily `-At` time, but the script also starts it right away.

`-RunNow` still requires the same logged-in user session as normal task runs. Display Dimmer must already be running in that session, because the CLI sends the command to the running app through Local automation.

You can also start an already-registered task manually:

```powershell
Start-ScheduledTask -TaskName "Display Dimmer Brightness Example"
```

## Scheduled-Time Testing

If you want to test the scheduled trigger itself:

1. Pick a time at least one or two minutes in the future.
2. Run the create command without `-RunNow`.
3. Wait for the scheduled minute.

If you create a daily task for the current minute, Task Scheduler may treat today's run as already missed and wait until tomorrow.

## What The Task Runs

The registered task runs `DisplayDimmer.Cli.exe` with arguments like:

```text
--set-brightness 40 --target dd_your_stable_id --source cli
```

The CLI sends the command to the running Display Dimmer app, then exits. The example uses `--source cli` so the task behaves like a manual override if a schedule or app rule is active.

## Check Whether It Ran

Check task status:

```powershell
Get-ScheduledTaskInfo -TaskName "Display Dimmer Brightness Example" |
  Select-Object LastRunTime, LastTaskResult, NextRunTime, NumberOfMissedRuns
```

Useful result codes:

| Result | Meaning |
|---:|---|
| `0` | Task ran and Display Dimmer CLI returned success. |
| `1` | Invalid CLI arguments. |
| `2` | Display Dimmer app or Local automation unavailable. |
| `3` | Target not found. Run `--list-displays` again and use the current target ID. Prefer a `dd_...` value for saved tasks. |
| `4` | Unsupported command or operation. |
| `5` | Operation failed. |
| `6` | Partial success. |
| `7` | Local automation timeout. |

If `LastTaskResult` is `3`, the task ran but the target ID was wrong or the display is disconnected.

## Manual Task Scheduler Setup

1. Open Task Scheduler.
2. Create Basic Task.
3. Choose the trigger.
4. Choose Start a program.
5. Program/script: the path returned by this PowerShell command:

```powershell
$cliPath = (Get-Command DisplayDimmer.Cli.exe -ErrorAction Stop).Source
$cliPath
```

6. Arguments:

```text
--set-brightness 40 --target dd_your_stable_id --source cli
```

7. Open task properties.
8. Select "Run only when user is logged on".

Use `--json` if another script needs to inspect success, partial success, or failures.

## Custom CLI Path

The script normally resolves the installed `DisplayDimmer.Cli.exe` command automatically. Use `-CliPath` only when testing a source-built CLI or a custom install path.

If another script needs the exact command-line tool path, resolve it with:

```powershell
$cliPath = (Get-Command DisplayDimmer.Cli.exe -ErrorAction Stop).Source
```

Then pass it explicitly:

```powershell
powershell -ExecutionPolicy Bypass -File ".\examples\task-scheduler\Create-DisplayDimmerBrightnessTask.ps1" `
  -CliPath $cliPath `
  -Target dd_your_stable_id `
  -Brightness 40 `
  -At "19:00"
```
