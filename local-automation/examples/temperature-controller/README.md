# Cooperative Temperature Controller

This PowerShell example uses API 1.1 to hold a requested color temperature while cooperating with Display Dimmer's temperature rules. It detects capabilities from the **running app**, handles each physical display independently, refreshes standby intent, and releases only its own source during cleanup.

Requirements: Display Dimmer 2.2.10 or later advertising the temperature capabilities, Pro unlocked, Local automation enabled, and the app running in the same Windows user session. No additional PowerShell modules are required.

## Run

List displays and copy a stable `dd_...` physical-display or linked-group target:

```powershell
DisplayDimmer.Cli.exe --list-displays
```

From this example folder:

```powershell
.\temperature-controller.ps1 -Target dd_your_stable_id -Kelvin 4000 -DurationSeconds 60
```

The example runs for 60 seconds by default. It changes live temperature while running, then releases its named source; it never saves temperature or changes brightness, contrast, DDC preferences, or rule definitions. `-Target all` and `-Target primary` are accepted, but stable IDs are preferred. Choose a distinct `-Source` for independent controllers. For a source-built CLI, pass its actual path with `-CliPath` and use the app from the same build.

## Behavior

1. Detect `temperature`, `temperature-kelvin`, and `external-temperature` in the running app's capabilities. Protocol `--api-version` alone is insufficient.
2. Read targeted state once per second. Owners `perApp`, `schedule`, or `manual` mean temperature standby. Brightness-only ownership does not.
3. Send named `--set-temperature` when external control is allowed, or `--update-external-temperature` while standing by. The app rechecks ownership atomically, so a rule starting after the read still wins.
4. Check exit codes and JSON results. Stop on errors; skip individually unavailable temperature controls.
5. Release only this source using the physical target IDs actually touched, in `finally`. A newer source's value cannot be cleared by this release.

Intent is fresh for five seconds. One-second refresh suits a small number of displays; many slow operations require budgeting the refresh cadence. Watch cannot be the heartbeat timer because unchanged state emits no events.

An already-applied tint can stay after freshness expires if nothing replaces it. Once a rule/manual action replaces it, expired intent cannot return. Normal completion releases explicitly. Ctrl+C normally runs cleanup, but terminating the host, a crash, or an unavailable app can prevent it. A follow-up source-specific release is safe:

```powershell
DisplayDimmer.Cli.exe --resume-temperature --target dd_your_stable_id --source temperature-example --json
```

Kelvin is an approximate target, not a calibrated measurement. The app rounds to native tint and reports `requestedTemperatureKelvin`, accepted `temperature`, and `effectiveTemperature`; a deferred/refreshed result is not a visible hardware change.

For manual buttons, omit the named source. Add `--save` only to intentionally change the saved manual baseline; `persistenceStatus: "queued"` means scheduled, not completed, disk persistence. Named cooperative sources cannot save. See the [temperature contract](../../docs/cli-api-v1.md#temperature-control-api-11) for relative adjustments, reset, and resume.
