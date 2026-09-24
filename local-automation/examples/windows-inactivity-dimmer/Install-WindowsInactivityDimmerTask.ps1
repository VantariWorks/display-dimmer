[CmdletBinding()]
param(
    # These values are passed to Start-WindowsInactivityDimmer.ps1 at sign-in.
    [ValidateRange(1, 1440)]
    [int]$IdleMinutes = 5,

    [Alias("SetBrightness")]
    [ValidateRange(0, 100)]
    [int]$DimBrightness = 20,

    [ValidateRange(1, 60)]
    [int]$PollSeconds = 1,

    # Pass -DryRun to the watcher so the task cannot change brightness.
    [switch]$DryRun,

    # Optional exact CLI path if the app execution alias is unavailable.
    [string]$CliPath,

    [string]$TaskName = "Display Dimmer Inactivity Example",

    [ValidateRange(0, 3600)]
    [int]$DelaySeconds = 30,

    # Hide the long-running PowerShell window after testing it visibly.
    [switch]$Hidden,

    # Needed only when replacing a task with the same name.
    [switch]$Force,

    [switch]$RunNow,

    # Show the configuration without registering or starting a task.
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

$watcher = Join-Path $PSScriptRoot "Start-WindowsInactivityDimmer.ps1"
if (-not (Test-Path -LiteralPath $watcher)) {
    throw "The inactivity dimmer script was not found: $watcher"
}
$watcher = (Resolve-Path -LiteralPath $watcher).ProviderPath

if (-not [string]::IsNullOrWhiteSpace($CliPath)) {
    if (-not (Test-Path -LiteralPath $CliPath)) {
        throw "DisplayDimmer.Cli.exe was not found: $CliPath"
    }
    $CliPath = (Resolve-Path -LiteralPath $CliPath).ProviderPath
}

$powershellExe = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"
if (-not (Test-Path -LiteralPath $powershellExe)) {
    throw "Windows PowerShell was not found: $powershellExe"
}

$user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$arguments = @()
if ($Hidden) {
    $arguments += "-WindowStyle Hidden"
}
$arguments += "-NoProfile"
$arguments += "-ExecutionPolicy Bypass"
$arguments += '-File "' + $watcher + '"'
$arguments += "-IdleMinutes $IdleMinutes"
$arguments += "-DimBrightness $DimBrightness"
$arguments += "-PollSeconds $PollSeconds"
if ($DryRun) {
    $arguments += "-DryRun"
}
if (-not [string]::IsNullOrWhiteSpace($CliPath)) {
    $arguments += '-CliPath "' + $CliPath + '"'
}
$argumentText = [string]::Join(" ", $arguments)

Write-Host "Task: $TaskName"
Write-Host "User: $user (interactive session, limited privileges)"
Write-Host "Trigger: at sign-in, after $DelaySeconds second(s)"
Write-Host "Program: $powershellExe"
Write-Host "Arguments: $argumentText"
Write-Host "Task lifetime: no time limit; no overlapping instance"

if ($WhatIf) {
    Write-Host "WhatIf: no task was registered or started."
    return
}

$action = New-ScheduledTaskAction -Execute $powershellExe -Argument $argumentText
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $user
$trigger.Delay = "PT$($DelaySeconds)S"
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Seconds 0) `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1)

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings `
    -Description "Display Dimmer example: dim eligible displays after Windows user inactivity." `
    -Force:$Force | Out-Null

Write-Host "Task registered. Sign out and back in, or use Start-ScheduledTask -TaskName `"$TaskName`" to test."
if ($RunNow) {
    Start-ScheduledTask -TaskName $TaskName
    Write-Host "Task started."
}
