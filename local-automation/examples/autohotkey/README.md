# AutoHotkey Shortcuts

This example uses AutoHotkey v2 to call `DisplayDimmer.Cli.exe` from keyboard shortcuts.

The supplied hotkeys remain brightness/DDC-focused. For API 1.1 temperature commands you can bind separately, see the [temperature reference](../../docs/cli-api-v1.md#temperature-control-api-11). Manual temperature hotkeys should use manual-source semantics rather than cooperative background ownership.

## Requirements

- Display Dimmer is running.
- Local automation is enabled in Display Dimmer.
- Display Dimmer Pro is unlocked.
- AutoHotkey v2 is installed.
- `DisplayDimmer.Cli.exe --list-displays` works from PowerShell or Command Prompt.

## Configure The Target

The sample defaults to the Windows primary display:

```ahk
Target := "primary"
```

For a fixed monitor, run:

```powershell
DisplayDimmer.Cli.exe --list-displays
```

Then replace `primary` with the stable `dd_...` target ID for that display.

## Included Hotkeys

- `Ctrl+Alt+Up`: increase brightness by 10.
- `Ctrl+Alt+Down`: decrease brightness by 10.
- `Ctrl+Alt+1`: set brightness to 25.
- `Ctrl+Alt+2`: set brightness to 50.
- `Ctrl+Alt+3`: set brightness to 75.
- `Ctrl+Alt+0`: set brightness to 0.
- `Ctrl+Alt+G`: set software/gamma brightness to 0.
- `Ctrl+Alt+D`: enable DDC/CI for the target display.
- `Ctrl+Alt+Shift+D`: disable DDC/CI for the target display.
- `Ctrl+Alt+L`: open a console and list display targets.

## Toggle Dim And Restore

For a hotkey that dims one fixed display on first press and restores its previous live brightness on the next press, use the [toggle dim and restore recipe](../automation-recipes/#toggle-dim-and-restore-one-display) as the command body.

That two-press recipe conditionally resumes a rule it temporarily interrupted on API 1.2. The supplied one-way hotkeys remain intentional manual actions and do not automatically release automation.

## Recall A Saved Preset

On Display Dimmer 2.2.12, save a Pro preset in Settings > Presets, check the
running app's `presets` and `list-presets` capabilities, and list its stable ID:

```powershell
DisplayDimmer.Cli.exe --list-presets --json
```

You can add a shortcut to the sample after its existing helper functions:

```ahk
^!e::RunDisplayDimmer('--apply-preset "Evening"')
```

Replace `Evening` with the saved preset name or ID. The helper already adds
`--json`. New presets carry their saved display targets; do not append the sample's
`Target` or `--source cli`. Only older presets with `requiresTarget: true` need
one explicit target. This recalls a manual preset; omitted levels stay unchanged.
See the [preset reference](../../docs/cli-api-v1.md#saved-preset-recall-api-12).

## Run

Double-click `DisplayDimmerHotkeys.ahk`, or right-click it and choose **Run Script**.
