# Automation Recipes

These recipes show common ways to control Display Dimmer from scripts and local automation tools.

Use these examples when you want a practical command pattern, not a full sample project.

The recipes below remain brightness-focused. For API 1.1 native/Kelvin color-temperature commands, see the [temperature reference](../../docs/cli-api-v1.md#temperature-control-api-11) and separate [temperature controller example](../temperature-controller/). Temperature has independent ownership; do not reuse brightness standby flags to decide temperature control.

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

Use this when normal `--set-brightness 0` is not dark enough for a hotkey, macro button, no-motion dimmer, idle script, or other local automation. This is an advanced, explicit opt-in that combines low monitor hardware brightness with Display Dimmer software/gamma dimming.

Normal `--set-ddc disabled` deliberately does not create this stack. When it changes the display from DDC enabled to disabled, it sets and saves gamma brightness at a neutral 100% so a user cannot accidentally place low gamma brightness over an already-dim monitor; repeating it while DDC/CI is already disabled is a no-op. The extra-dark sequence establishes that safe baseline first, writes raw monitor brightness explicitly, and only then applies gamma dimming.

A few details matter:

- This works only on a physical display whose DDC/CI path supports hardware brightness VCP `0x10`. It is not a linked-group command.
- VCP `0x10` uses the monitor's raw range, not a guaranteed percentage. Read `vcpMax`, calculate a cautious value, and start brighter than you think you need.
- This recipe requires Settings > General > **Reset DDC/CI displays to default brightness on exit** to be turned off. Otherwise the asynchronous safety reset can restore hardware brightness to 100 after the script writes its low raw value.
- Capture Display Dimmer brightness, DDC/CI mode, and raw hardware brightness before dimming. The DDC-off safety handoff can save a 100% baseline, so the restore uses `--save` to put the captured brightness back.
- Use `--source cli` when extra-dark dimming should behave like a manual override. For no-motion dimming, this prevents schedules and app rules from immediately reasserting over an empty-room dim.
- Test the sequence interactively on one display and keep the restore commands ready. Extremely low hardware and gamma values can make the screen difficult to recover.

Capture state and choose cautious starting levels:

```powershell
$cli = "DisplayDimmer.Cli.exe"
$target = "dd_your_stable_id"

function Invoke-DisplayDimmerJson {
    param([string[]]$Arguments)

    $response = & $cli @Arguments | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0 -or $null -eq $response -or -not $response.success) {
        $message = if ($null -ne $response) { $response.message } else { "No JSON response." }
        throw "Display Dimmer command failed: $message"
    }

    return $response
}

$stateResponse = Invoke-DisplayDimmerJson -Arguments @(
    "--get-state", "--target", $target, "--json"
)
$displayState = @($stateResponse.displays)[0]
if ($null -eq $displayState) {
    throw "The target did not return a physical display state."
}

$vcpResponse = Invoke-DisplayDimmerJson -Arguments @(
    "--get-vcp", "0x10", "--target", $target, "--json"
)
$vcpState = @($vcpResponse.results)[0]
if ($null -eq $vcpState -or $null -eq $vcpState.vcpValue -or $null -eq $vcpState.vcpMax) {
    throw "The monitor did not return raw VCP 0x10 brightness and maximum values."
}

$previousBrightness = [int]$displayState.brightness
$previousDdcEnabled = [bool]$displayState.ddcEnabled
$previousHardwareBrightness = [uint32]$vcpState.vcpValue
$hardwareMaximum = [uint32]$vcpState.vcpMax
if ($hardwareMaximum -eq 0) {
    throw "The monitor reported an unusable VCP 0x10 maximum."
}

# Start at 10% of the monitor-reported raw range and 20% gamma.
# Tune one layer at a time only after confirming the restore works.
$extraDarkHardware = [Math]::Max(1, [int][Math]::Round($hardwareMaximum * 0.10))
$extraDarkGamma = 20
```

Apply extra-dark dimming:

```powershell
# 1. Neutralize gamma and safely disable app-owned DDC brightness.
Invoke-DisplayDimmerJson -Arguments @(
    "--set-brightness", "100", "--brightness-mode", "gamma",
    "--target", $target, "--source", "cli", "--json"
) | Out-Null

# 2. Lower the hardware layer explicitly and require matching readback.
Invoke-DisplayDimmerJson -Arguments @(
    "--set-vcp", "0x10", "$extraDarkHardware",
    "--target", $target, "--verify", "--json"
) | Out-Null

# 3. Add the software/gamma layer deliberately.
Invoke-DisplayDimmerJson -Arguments @(
    "--set-brightness", "$extraDarkGamma", "--brightness-mode", "gamma",
    "--target", $target, "--source", "cli", "--json"
) | Out-Null
```

Why this order: the first command leaves gamma neutral and clears app-owned DDC brightness work. Raw VCP `0x10` then lowers only the monitor hardware layer and verifies the monitor's readback. The final command is the explicit opt-in to stack software/gamma dimming over that low hardware value.

Restore depends on the display's original DDC/CI state.

Always neutralize gamma first so the screen becomes easier to see before restoring hardware:

```powershell
Invoke-DisplayDimmerJson -Arguments @(
    "--set-brightness", "100", "--brightness-mode", "gamma",
    "--target", $target, "--source", "cli", "--json"
) | Out-Null
```

If DDC/CI was originally enabled, restore the captured Display Dimmer brightness through its normal DDC-capable route. `--save` replaces the temporary 100% safety baseline:

```powershell
if ($previousDdcEnabled) {
    Invoke-DisplayDimmerJson -Arguments @(
        "--set-brightness", "$previousBrightness", "--brightness-mode", "ddc",
        "--target", $target, "--source", "cli", "--save", "--json"
    ) | Out-Null
}
```

If DDC/CI was originally disabled, restore the exact captured raw hardware value first, then restore and save the previous gamma brightness while keeping DDC disabled:

```powershell
if (-not $previousDdcEnabled) {
    Invoke-DisplayDimmerJson -Arguments @(
        "--set-vcp", "0x10", "$previousHardwareBrightness",
        "--target", $target, "--verify", "--json"
    ) | Out-Null

    Invoke-DisplayDimmerJson -Arguments @(
        "--set-brightness", "$previousBrightness", "--brightness-mode", "gamma",
        "--target", $target, "--source", "cli", "--save", "--json"
    ) | Out-Null
}
```

For multiple displays, repeat the capture, dim, and restore logic independently for each physical display. Do not reuse one monitor's raw value or `vcpMax` for another monitor.

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
