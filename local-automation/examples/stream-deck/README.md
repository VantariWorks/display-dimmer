# Stream Deck And Macro Button Examples

These examples show how to run `DisplayDimmer.Cli.exe` from Stream Deck or another macro tool that can launch a program with arguments.

Stream Deck buttons are user-triggered actions, so the examples use manual override behavior. That means they can interrupt active Display Dimmer schedules or app rules for the targeted displays.

## Requirements

- Display Dimmer is running.
- Local automation is enabled in Display Dimmer.
- Display Dimmer Pro is unlocked.
- `DisplayDimmer.Cli.exe --list-displays` works from PowerShell.

## Find The CLI Path

Usually you can use `DisplayDimmer.Cli.exe` directly. If your macro tool needs a full path, run this in PowerShell:

```powershell
(Get-Command DisplayDimmer.Cli.exe -ErrorAction Stop).Source
```

Use the returned path as the macro button's program/app/file.

## Stream Deck Setup

Create a **System > Open** action.

Use either:

```text
Program/App/File:
DisplayDimmer.Cli.exe
```

or the full path returned by PowerShell.

Put the command flags in the arguments field if your macro tool has one. If your tool has only one command box, put the program first and the arguments after it.

## Recipes

### Set The Primary Display To 40 Percent

Program:

```text
DisplayDimmer.Cli.exe
```

Arguments:

```text
--set-brightness 40 --target primary --source cli
```

Use `primary` when the button should follow the current Windows primary display.

### Increase The Primary Display By 10 Percent

Program:

```text
DisplayDimmer.Cli.exe
```

Arguments:

```text
--adjust-brightness 10 --target primary --source cli
```

### Decrease The Primary Display By 10 Percent

Program:

```text
DisplayDimmer.Cli.exe
```

Arguments:

```text
--adjust-brightness -10 --target primary --source cli
```

### Dim All Displays To 0 Percent

Program:

```text
DisplayDimmer.Cli.exe
```

Arguments:

```text
--set-brightness 0 --target all --source cli
```

### Dim One Fixed Display

First copy the display's stable `dd_...` target ID:

```powershell
DisplayDimmer.Cli.exe --list-displays
```

Program:

```text
DisplayDimmer.Cli.exe
```

Arguments:

```text
--set-brightness 20 --target dd_your_stable_id --source cli
```

Use a stable `dd_...` ID when the button should always control the same physical display.

### Toggle Dim And Restore

For a button that dims one fixed display on first press and restores its previous live brightness on the next press, use the [toggle dim and restore recipe](../automation-recipes/#toggle-dim-and-restore-one-display).

### Dim A Linked Display Group

Linked display groups also have stable `dd_...` target IDs in `--list-displays`.

Program:

```text
DisplayDimmer.Cli.exe
```

Arguments:

```text
--set-brightness 20 --target dd_your_linked_group_id --source cli
```

The running Display Dimmer app expands the linked group to its currently connected member displays.

### Force Software/Gamma Dimming

Program:

```text
DisplayDimmer.Cli.exe
```

Arguments:

```text
--set-brightness 0 --brightness-mode gamma --target dd_your_stable_id --source cli
```

Use this only when you intentionally want Display Dimmer to switch that display away from DDC/CI and use the software/gamma brightness route.

### Force DDC/CI Brightness

Program:

```text
DisplayDimmer.Cli.exe
```

Arguments:

```text
--set-brightness 70 --brightness-mode ddc --target dd_your_stable_id --source cli
```

Use this only when you intentionally want Display Dimmer to enable DDC/CI for that display first.

## Debugging A Button

Macro tools often hide command output. If a button appears to do nothing, run the same command in PowerShell first.

You can also use PowerShell as the macro action and write a log file.

Program:

```text
powershell.exe
```

Arguments:

```text
-NoProfile -ExecutionPolicy Bypass -Command "DisplayDimmer.Cli.exe --set-brightness 40 --target primary --source cli --json --pretty *> $env:TEMP\DisplayDimmer-StreamDeck.log; exit $LASTEXITCODE"
```

Then check:

```powershell
notepad $env:TEMP\DisplayDimmer-StreamDeck.log
```

## Troubleshooting

- `appUnavailable`: Display Dimmer is not running, Local automation is off, Pro is locked, or the macro tool is running as a different Windows user.
- `targetNotFound`: run `DisplayDimmer.Cli.exe --list-displays` again and copy the current `targetId`.
- `partial=true` with `errorCode=partialSuccess`: at least one target worked and at least one failed. Add `--json --pretty` to see per-display results.
- If direct `DisplayDimmer.Cli.exe` does not launch, use the full path from `(Get-Command DisplayDimmer.Cli.exe).Source`.
