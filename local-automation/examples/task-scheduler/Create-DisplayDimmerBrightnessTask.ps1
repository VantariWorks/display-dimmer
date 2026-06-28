param(
    # Optional explicit path or command name for DisplayDimmer.Cli.exe.
    [string]$CliPath,

    # Display Dimmer target id to control. Prefer a stable dd_... id from --list-displays.
    [string]$Target,

    # Brightness percentage the scheduled task will apply.
    [ValidateRange(0, 100)]
    [int]$Brightness = 50,

    # Windows Task Scheduler task name to create or replace.
    [string]$TaskName = "Display Dimmer Brightness Example",

    # Daily start time in 24-hour HH:mm format.
    [string]$At = "19:00",

    # Run the created task immediately after registration.
    [switch]$RunNow,

    # Print the task details without registering it.
    [switch]$WhatIf,

    # Skip the preflight CLI target validation.
    [switch]$SkipValidation
)

$ErrorActionPreference = "Stop"

function Resolve-DefaultCliPath {
    $installedCommand = Get-Command "DisplayDimmer.Cli.exe" -CommandType Application -ErrorAction SilentlyContinue
    if ($null -ne $installedCommand) {
        return $installedCommand.Source
    }

    $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $releasePath = Join-Path $repoRoot "DisplayDimmer.Cli\bin\x64\Release\net8.0-windows10.0.19041.0\DisplayDimmer.Cli.exe"
    if (Test-Path -LiteralPath $releasePath) {
        return (Resolve-Path -LiteralPath $releasePath).ProviderPath
    }

    $debugPath = Join-Path $repoRoot "DisplayDimmer.Cli\bin\x64\Debug\net8.0-windows10.0.19041.0\DisplayDimmer.Cli.exe"
    if (Test-Path -LiteralPath $debugPath) {
        return (Resolve-Path -LiteralPath $debugPath).ProviderPath
    }

    return $releasePath
}

function Resolve-CliPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return Resolve-DefaultCliPath
    }

    if (Test-Path -LiteralPath $Path) {
        return (Resolve-Path -LiteralPath $Path).ProviderPath
    }

    $command = Get-Command $Path -CommandType Application -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        return $command.Source
    }

    return $Path
}

function Show-Usage {
    Write-Host "Usage:"
    Write-Host "  powershell -ExecutionPolicy Bypass -File `".\examples\task-scheduler\Create-DisplayDimmerBrightnessTask.ps1`" -Target <targetId> -Brightness 40 -At `"19:00`""
    Write-Host ""
    Write-Host "Optional:"
    Write-Host "  -CliPath <DisplayDimmer.Cli.exe path or command>"
    Write-Host "  -TaskName `"Display Dimmer Brightness Example`""
    Write-Host "  -RunNow"
    Write-Host "  -WhatIf"
    Write-Host "  -SkipValidation"
    Write-Host ""
    Write-Host "Use DisplayDimmer.Cli.exe --list-displays to copy a targetId. Prefer a dd_... target ID for saved tasks."
}

$CliPath = Resolve-CliPath -Path $CliPath

if ([string]::IsNullOrWhiteSpace($Target)) {
    Show-Usage
    throw "Target is required. Pass a targetId from DisplayDimmer.Cli.exe --list-displays."
}

if (-not (Test-Path -LiteralPath $CliPath)) {
    Show-Usage
    throw "DisplayDimmer.Cli.exe was not found: $CliPath"
}

if (-not $SkipValidation) {
    Write-Host "Validating target with Display Dimmer CLI..."
    $validationOutput = & $CliPath --get-state --target $Target --json
    $validationExit = $LASTEXITCODE
    if ($validationExit -ne 0) {
        Write-Host $validationOutput
        throw "Display Dimmer CLI could not find target '$Target'. Run DisplayDimmer.Cli.exe --list-displays and copy the targetId from your machine."
    }
}

function ConvertTo-TaskArgumentText {
    param([string[]]$Arguments)

    $quoted = New-Object System.Collections.Generic.List[string]
    foreach ($arg in $Arguments) {
        if ($arg -match '[\s"]') {
            $quoted.Add('"' + ($arg -replace '"', '\"') + '"')
        } else {
            $quoted.Add($arg)
        }
    }

    return [string]::Join(" ", $quoted)
}

$runAt = [DateTime]::Parse($At)
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$cliArguments = ConvertTo-TaskArgumentText @(
    "--set-brightness",
    $Brightness.ToString([System.Globalization.CultureInfo]::InvariantCulture),
    "--target",
    $Target,
    "--source",
    "cli"
)

Write-Host "Task name: $TaskName"
Write-Host "User: $identity"
Write-Host "CLI: $CliPath"
Write-Host "Arguments: $cliArguments"
Write-Host "Daily time: $($runAt.ToShortTimeString())"
if ($runAt.TimeOfDay -le (Get-Date).TimeOfDay) {
    Write-Host "Note: that time has already passed today, or is too close to the current minute. The daily trigger will normally run next tomorrow. Use Start-ScheduledTask for an immediate test."
}

if ($WhatIf) {
    Write-Host "WhatIf was set. No task was registered."
    return
}

$action = New-ScheduledTaskAction -Execute $CliPath -Argument $cliArguments
$trigger = New-ScheduledTaskTrigger -Daily -At $runAt
$principal = New-ScheduledTaskPrincipal -UserId $identity -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings `
    -Description "Display Dimmer Local automation example. Runs only while you are logged on." `
    -Force | Out-Null

Write-Host "Task registered."
Write-Host "Test now with:"
Write-Host "  Start-ScheduledTask -TaskName `"$TaskName`""

if ($RunNow) {
    Start-ScheduledTask -TaskName $TaskName
    Write-Host "Task started."
}
