# Automation Recipes

These recipes show common ways to control Display Dimmer from scripts and local automation tools.

Use these examples when you want a practical command pattern, not a full sample project.

## Requirements

- Display Dimmer is running.
- Local automation is enabled in Display Dimmer.
- Display Dimmer Pro is unlocked.
- `DisplayDimmer.Cli.exe --list-displays` works from PowerShell.

## Choose Stable Targets

For scripts you plan to keep, prefer `dd_...` target IDs:

```powershell
DisplayDimmer.Cli.exe --list-displays
```

Use:

- `primary` for a quick shortcut that follows the current Windows primary display.
- `all` when the script should target every currently connected display. Check per-display results because individual displays can still fail.
- `dd_...` for physical displays and linked display groups in durable automation.
- `display_1`, `display_2`, etc. only for quick tests.

## Manual Override

Use this when the script should behave like a user action and take control immediately.

```powershell
DisplayDimmer.Cli.exe --set-brightness 45 --target dd_your_stable_id --source cli
```

Omitting `--source` has the same manual-override behavior. Passing `--source cli` makes the intent clearer in saved scripts.

Manual override can interrupt active schedules for the targeted displays and suspend active app rules for the targeted displays.

## Toggle Dim And Restore One Display

Use this pattern for a macro button that dims one fixed display the first time you press it, then restores that display's previous live brightness the next time you press it.

This recipe uses one state file per target. It only deletes the saved state after the restore command succeeds, so a failed restore does not lose the previous brightness.

```powershell
$target = "dd_your_stable_id"
$dimBrightness = 5
$source = "cli"

$stateDir = Join-Path $env:LOCALAPPDATA "DisplayDimmer\AutomationRecipes"
$safeTarget = $target -replace '[^A-Za-z0-9_.-]', '_'
$stateFile = Join-Path $stateDir ("toggle-" + $safeTarget + ".json")

New-Item -ItemType Directory -Path $stateDir -Force | Out-Null

if (Test-Path -LiteralPath $stateFile) {
    $saved = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
    $restoreBrightness = [int]$saved.brightness

    $restoreResult = DisplayDimmer.Cli.exe --set-brightness $restoreBrightness --target $target --source $source --json | ConvertFrom-Json
    if ($restoreResult.success) {
        Remove-Item -LiteralPath $stateFile -Force
        exit 0
    }

    $restoreResult | ConvertTo-Json -Depth 8
    exit 1
}

$state = DisplayDimmer.Cli.exe --get-state --target $target --json | ConvertFrom-Json
$displays = @($state.displays)
if (-not $state.success -or $displays.Count -lt 1 -or $null -eq $displays[0].brightness) {
    $state | ConvertTo-Json -Depth 8
    exit 1
}

$currentBrightness = [int]$displays[0].brightness

@{
    target = $target
    brightness = $currentBrightness
    savedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
} | ConvertTo-Json | Set-Content -LiteralPath $stateFile -Encoding UTF8

$dimResult = DisplayDimmer.Cli.exe --set-brightness $dimBrightness --target $target --source $source --json | ConvertFrom-Json
if ($dimResult.success) {
    exit 0
}

Remove-Item -LiteralPath $stateFile -Force -ErrorAction SilentlyContinue
$dimResult | ConvertTo-Json -Depth 8
exit 1
```

Use a physical `dd_...` target ID for this simple version. If you want to toggle `all` or a linked group, save and restore each returned display separately so displays with different brightness levels do not all restore to the same value.

## Cooperative Sensor Or Background Script

Use a stable source name when a background automation should cooperate with Display Dimmer schedules and app rules.

```powershell
DisplayDimmer.Cli.exe --set-brightness 45 --target dd_your_stable_id --source desk-light-sensor
```

If Display Dimmer automation does not own the target, the command can apply immediately.

If an uninterrupted schedule or app rule already owns the target, Display Dimmer stands the external source down and refreshes its handoff value instead of interrupting the rule.

## Handoff-Only Update

Use `--update-external-brightness` when your script already knows Display Dimmer automation owns the target and should not be interrupted.

```powershell
DisplayDimmer.Cli.exe --update-external-brightness 45 --target dd_your_stable_id --source desk-light-sensor
```

This does not move the display. It only refreshes the value Display Dimmer can return to when the current schedule or app rule ends.

## Decide Per Display

When a script controls more than one display, do not assume all targets are in the same automation state.

Read state:

```powershell
$state = DisplayDimmer.Cli.exe --get-state --target all --json | ConvertFrom-Json
```

Then decide per display:

```powershell
foreach ($display in $state.displays) {
    $target = $display.targetId
    $brightness = 45
    $source = "desk-light-sensor"

    $perAppOwns = $display.perAppActive -and -not $display.perAppInterrupted
    $scheduleOwns = $display.scheduleActive -and -not $display.scheduleInterrupted

    if ($perAppOwns -or $scheduleOwns) {
        DisplayDimmer.Cli.exe --update-external-brightness $brightness --target $target --source $source --json | Out-Null
    } else {
        DisplayDimmer.Cli.exe --set-brightness $brightness --target $target --source $source --json | Out-Null
    }
}
```

This is the safest pattern for light sensors and other background controllers that should yield to Display Dimmer automation. For presence or no-motion dimming, use manual override mode unless you explicitly want schedules and app rules to win.

## Extra-Dark Dimming

Use this when normal `--set-brightness 0` is not dark enough for a hotkey, macro button, no-motion dimmer, idle script, or other local automation. The sequence lowers monitor hardware brightness first, then keeps Display Dimmer on software/gamma at the same low level.

A few details matter:

- This adds a hardware dimming layer only on displays where DDC/CI brightness is available. Displays without DDC/CI can still use normal software/gamma dimming, but there is no hardware layer to stack.
- This recipe requires Settings > General > **Reset DDC/CI displays to default brightness on exit** to be turned off. If it is on, disabling DDC/CI can restore hardware brightness to 100 and prevent the deep-dim stack from working.
- Capture `brightness` and `ddcEnabled` before dimming. The script temporarily changes DDC/CI state while it dims, then restores each display back to its original mode.
- Use `--source cli` when extra-dark dimming should behave like a manual override. For no-motion dimming, this prevents schedules and app rules from immediately reasserting over an empty-room dim.

Deep dim one display:

```powershell
$target = "dd_your_stable_id"

DisplayDimmer.Cli.exe --set-brightness 0 --brightness-mode ddc --target $target --source cli --json | Out-Null
DisplayDimmer.Cli.exe --set-ddc disabled --target $target --json | Out-Null
```

Why this order: `--brightness-mode ddc` lowers the hardware layer while keeping Display Dimmer's brightness state in sync. `--set-ddc disabled` then carries that same low level into software/gamma. Do not use raw VCP `0x10` for this recipe; raw VCP bypasses Display Dimmer's brightness state and is harder to restore cleanly.

Restore depends on the display's original DDC/CI state.

If DDC/CI was originally enabled, restore directly through the DDC/CI route:

```powershell
DisplayDimmer.Cli.exe --set-brightness $previousBrightness --brightness-mode ddc --target $target --source cli --json | Out-Null
```

If DDC/CI was originally disabled, briefly restore the hardware layer first, switch DDC/CI back off, then restore the previous software/gamma brightness. That keeps the display's original software/gamma preference while preventing the monitor's hardware brightness from staying at the dimmed level:

```powershell
DisplayDimmer.Cli.exe --set-brightness 100 --brightness-mode ddc --target $target --source cli --json | Out-Null
DisplayDimmer.Cli.exe --set-ddc disabled --target $target --json | Out-Null
DisplayDimmer.Cli.exe --set-brightness $previousBrightness --brightness-mode gamma --target $target --source cli --json | Out-Null
```

For multiple displays, read state first and save `brightness` plus `ddcEnabled` for each physical display. Then run the dim sequence per display instead of assuming every monitor started in the same DDC/CI mode:

```powershell
$state = DisplayDimmer.Cli.exe --get-state --target all --json | ConvertFrom-Json

foreach ($display in $state.displays) {
    $target = $display.targetId
    DisplayDimmer.Cli.exe --set-brightness 0 --brightness-mode ddc --target $target --source cli --json | Out-Null
    DisplayDimmer.Cli.exe --set-ddc disabled --target $target --json | Out-Null
}
```

## Linked Display Group

Linked display groups have their own `dd_...` target IDs in `--list-displays`.

```powershell
DisplayDimmer.Cli.exe --set-brightness 30 --target dd_your_linked_group_id --source cli
```

Display Dimmer expands the linked group to its currently connected member displays. Each member still returns its own success or error result.

Use linked group target IDs when a script should treat a set of displays as one logical target.

## Startup Or Scheduled Task

For a simple startup action, use Task Scheduler and call the CLI with a stable target ID.

Example arguments:

```text
--set-brightness 45 --target dd_your_stable_id --source cli
```

For cooperative sensor or background bridge scripts, use a named source:

```text
--set-brightness 45 --target dd_your_stable_id --source desk-light-sensor
```

Task Scheduler should run as the same Windows user as Display Dimmer. Use "Run only when user is logged on" for desktop-session automation.

## Debug A Recipe

Add JSON while testing:

```powershell
DisplayDimmer.Cli.exe --set-brightness 45 --target dd_your_stable_id --source cli --json --pretty
```

Common results:

- `success=true`: the command worked.
- `partial=true` with `errorCode=partialSuccess`: at least one target worked and at least one failed.
- `appUnavailable`: Display Dimmer is not running, Local automation is off, Pro is locked, or the process is running as another Windows user.
- `targetNotFound`: rerun `--list-displays` and copy the current `targetId`.
