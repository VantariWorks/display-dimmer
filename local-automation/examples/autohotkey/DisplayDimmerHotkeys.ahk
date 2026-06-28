#Requires AutoHotkey v2.0
#SingleInstance Force

; Display Dimmer must be running, and Local automation must be enabled.
; Use DisplayDimmer.Cli.exe --list-displays to find a stable dd_... target.
CliExe := "DisplayDimmer.Cli.exe"
Target := "primary"

RunDisplayDimmer(args)
{
    global CliExe

    ; Use cmd.exe so the packaged app execution alias resolves the same way it does in PowerShell/CMD.
    command := A_ComSpec . " /d /c " . Chr(34) . Chr(34) . CliExe . Chr(34) . " " . args . " --json" . Chr(34)
    RunWait(command, , "Hide")
}

SetBrightness(level)
{
    global Target
    RunDisplayDimmer("--set-brightness " . level . " --target " . Target)
}

AdjustBrightness(delta)
{
    global Target
    RunDisplayDimmer("--adjust-brightness " . delta . " --target " . Target)
}

SetDdc(enabled)
{
    global Target
    state := enabled ? "enabled" : "disabled"
    RunDisplayDimmer("--set-ddc " . state . " --target " . Target)
}

; Ctrl+Alt+Up/Down: adjust brightness on the target display.
^!Up::AdjustBrightness(10)
^!Down::AdjustBrightness(-10)

; Ctrl+Alt+1/2/3/0: set common brightness levels.
^!1::SetBrightness(25)
^!2::SetBrightness(50)
^!3::SetBrightness(75)
^!0::SetBrightness(0)

; Ctrl+Alt+G: force software/gamma brightness to 0.
^!g::RunDisplayDimmer("--set-brightness 0 --brightness-mode gamma --target " . Target)

; Ctrl+Alt+D / Ctrl+Alt+Shift+D: enable/disable DDC/CI for the target display.
^!d::SetDdc(true)
^!+d::SetDdc(false)

; Ctrl+Alt+L: open a console and list available display targets.
^!l::Run(A_ComSpec . " /k " . Chr(34) . CliExe . " --list-displays" . Chr(34))
