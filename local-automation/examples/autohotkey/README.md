# AutoHotkey Shortcuts

This example uses AutoHotkey v2 to call `DisplayDimmer.Cli.exe` from keyboard shortcuts.

## Requirements

- Display Dimmer is running.
- Local automation is enabled in Display Dimmer.
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

## Run

Double-click `DisplayDimmerHotkeys.ahk`, or right-click it and choose **Run Script**.
