param(
    # Serial port used by the Arduino, for example COM3 or COM7.
    [string]$Port = "COM3",

    # Display Dimmer target id to control. Prefer a stable dd_... id from --list-displays.
    [string]$Target,

    # Arduino serial speed. Must match Serial.begin(...) in the sketch.
    [int]$BaudRate = 9600,

    # Minutes without motion before the bridge dims the target display.
    [double]$IdleMinutes = 2,

    # Extra idle seconds; useful for quick testing without changing IdleMinutes.
    [int]$IdleSeconds = 0,

    # Brightness percentage to apply after the idle timeout.
    [int]$DimBrightness = 20,

    # Brightness to restore on motion. Use -1 to restore the startup/live baseline.
    [int]$RestoreBrightness = -1,

    # How often the bridge polls Display Dimmer for schedule/app-rule ownership.
    [int]$AutomationPollIntervalMs = 1000,

    # Print readings and intended commands without changing brightness.
    [switch]$DryRun,

    # Stand by while schedules/app rules own the target instead of treating no-motion as a manual override.
    [switch]$CooperateWithAutomation,

    # Legacy override switch. No-motion override is now the default unless -CooperateWithAutomation is used.
    [switch]$IgnoreAutomation,

    # Source label sent in cooperative mode so Display Dimmer automation handoff can identify this bridge.
    [string]$Source = "arduino-motion-sensor-lcd",

    # Optional explicit path or command name for DisplayDimmer.Cli.exe.
    [string]$CliPath
)

$ErrorActionPreference = "Stop"

function Resolve-CliPath {
    param([string]$ProvidedPath)

    if (-not [string]::IsNullOrWhiteSpace($ProvidedPath)) {
        if (Test-Path -LiteralPath $ProvidedPath) {
            return (Resolve-Path -LiteralPath $ProvidedPath).ProviderPath
        }

        $providedCommand = Get-Command $ProvidedPath -CommandType Application -ErrorAction SilentlyContinue
        if ($null -ne $providedCommand) {
            return $providedCommand.Source
        }

        return $ProvidedPath
    }

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

function Test-CliAvailable {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    if (Test-Path -LiteralPath $Path) {
        return $true
    }

    return $null -ne (Get-Command $Path -CommandType Application -ErrorAction SilentlyContinue)
}

function Clamp-Int {
    param(
        [int]$Value,
        [int]$Min,
        [int]$Max
    )

    if ($Value -lt $Min) { return $Min }
    if ($Value -gt $Max) { return $Max }
    return $Value
}

function New-DisplayRuntimeState {
    param(
        [string]$Automation = "unknown",
        $Brightness = $null
    )

    [pscustomobject]@{
        Automation = $Automation
        Brightness = $Brightness
    }
}

function Get-DisplayRuntimeState {
    try {
        # Ask the running app for the current brightness and automation owner.
        # The bridge still needs this in override mode so restore can use the
        # live brightness captured just before idle dimming.
        if ($DryRun) {
            return New-DisplayRuntimeState -Automation "none"
        }

        if (-not (Test-CliAvailable -Path $CliPath)) {
            return New-DisplayRuntimeState -Automation "unknown"
        }

        $stateOutput = & $CliPath --get-state --target $Target --json
        if ($LASTEXITCODE -ne 0) {
            return New-DisplayRuntimeState -Automation "unknown"
        }

        $stateText = ($stateOutput -join "").Trim()
        if ([string]::IsNullOrWhiteSpace($stateText)) {
            return New-DisplayRuntimeState -Automation "unknown"
        }

        $state = $stateText | ConvertFrom-Json
        if ($null -eq $state -or $null -eq $state.displays) {
            return New-DisplayRuntimeState -Automation "unknown"
        }

        $scheduleTakingControl = $false
        $automationInterrupted = $false
        $liveBrightness = $null

        foreach ($display in @($state.displays)) {
            if ($null -eq $liveBrightness -and $null -ne $display.brightness) {
                $liveBrightness = [int]$display.brightness
            }

            $perAppTakingControl = $display.perAppActive -eq $true -and $display.perAppInterrupted -ne $true
            if ($perAppTakingControl) {
                return New-DisplayRuntimeState -Automation "app-rule" -Brightness $liveBrightness
            }

            if ($display.perAppInterrupted -eq $true) {
                $automationInterrupted = $true
            }

            if ($display.scheduleActive -eq $true -and $display.scheduleInterrupted -ne $true) {
                $scheduleTakingControl = $true
            }

            if ($display.scheduleActive -eq $true -and $display.scheduleInterrupted -eq $true) {
                $automationInterrupted = $true
            }
        }

        if ($scheduleTakingControl) {
            return New-DisplayRuntimeState -Automation "schedule" -Brightness $liveBrightness
        }

        if ($automationInterrupted) {
            return New-DisplayRuntimeState -Automation "manual-override" -Brightness $liveBrightness
        }

        return New-DisplayRuntimeState -Automation "none" -Brightness $liveBrightness
    }
    catch {
        return New-DisplayRuntimeState -Automation "unknown"
    }
}

function Automation-OwnsDisplay {
    param([string]$Automation)

    return $Automation -eq "schedule" -or $Automation -eq "app-rule"
}

function Get-CommandSource {
    if ($CooperateWithAutomation -and -not $IgnoreAutomation) {
        return $Source
    }

    return "cli"
}

$lastArduinoStatus = $null
$lastArduinoBrightness = $null

function Set-ArduinoStatus {
    param([string]$Status)

    if ([string]::IsNullOrWhiteSpace($Status)) {
        return
    }

    if ($script:lastArduinoStatus -eq $Status) {
        return
    }

    try {
        if ($null -ne $serial -and $serial.IsOpen) {
            $serial.WriteLine("status=$Status")
            $script:lastArduinoStatus = $Status
        }
    }
    catch {
    }
}

function Set-ArduinoBrightness {
    param([int]$Brightness)

    if ($Brightness -lt 0 -or $Brightness -gt 100) {
        return
    }

    if ($script:lastArduinoBrightness -eq $Brightness) {
        return
    }

    try {
        if ($null -ne $serial -and $serial.IsOpen) {
            $serial.WriteLine("brightness=$Brightness")
            $script:lastArduinoBrightness = $Brightness
        }
    }
    catch {
    }
}

function Send-BrightnessCommand {
    param([int]$Brightness)

    # Motion is a simple apply-now demo: idle dims the target, motion restores it.
    if ($DryRun) {
        return [pscustomobject]@{
            ExitCode = 0
            OutputText = "dry-run"
        }
    }

    $cliArgs = @("--set-brightness", $Brightness, "--target", $Target)
    $commandSource = Get-CommandSource
    if (-not [string]::IsNullOrWhiteSpace($commandSource)) {
        $cliArgs += @("--source", $commandSource)
    }

    $output = & $CliPath @cliArgs
    $exitCode = $LASTEXITCODE
    $outputText = ($output -join " ").Trim()

    [pscustomobject]@{
        ExitCode = $exitCode
        OutputText = $outputText
    }
}

function Clear-BufferedSerialInput {
    try {
        if ($null -ne $serial -and $serial.IsOpen) {
            $serial.DiscardInBuffer()
        }
    }
    catch {
    }
}

$CliPath = Resolve-CliPath -ProvidedPath $CliPath
if ([string]::IsNullOrWhiteSpace($Target)) {
    throw "Target is required. Run DisplayDimmer.Cli.exe --list-displays and pass a stable dd_... ID, or pass primary for a quick primary-display test."
}

if (-not $DryRun -and -not (Test-CliAvailable -Path $CliPath)) {
    throw "DisplayDimmer.Cli.exe was not found at: $CliPath"
}

$DimBrightness = Clamp-Int -Value $DimBrightness -Min 0 -Max 100
if ($RestoreBrightness -ge 0) {
    $RestoreBrightness = Clamp-Int -Value $RestoreBrightness -Min 0 -Max 100
}

# IdleSeconds is mainly for quick testing. IdleMinutes is the normal product-like
# setting, with 2 minutes as the default.
$idleDurationSeconds = if ($IdleSeconds -gt 0) { $IdleSeconds } else { [int][Math]::Round($IdleMinutes * 60.0) }
if ($idleDurationSeconds -lt 1) {
    throw "Idle duration must be at least 1 second."
}

$serial = New-Object System.IO.Ports.SerialPort $Port, $BaudRate, "None", 8, "One"
$serial.ReadTimeout = 1000
$serial.NewLine = "`n"

$lastMotionAt = [DateTime]::UtcNow
$lastMotionState = $null
$lastAutomationPollAt = [DateTime]::MinValue
$lastRuntimeState = New-DisplayRuntimeState -Automation "unknown"
$lastStatusLogAt = [DateTime]::MinValue
$dimmedByBridge = $false
$capturedRestoreBrightness = $null

Write-Host "Opening $Port at $BaudRate baud. Close Arduino Serial Monitor first."
Write-Host "Target=$Target IdleSeconds=$idleDurationSeconds DimBrightness=$DimBrightness RestoreBrightness=$RestoreBrightness AutomationPollMs=$AutomationPollIntervalMs Source=$Source CommandSource=$(Get-CommandSource) DryRun=$DryRun CooperateWithAutomation=$CooperateWithAutomation IgnoreAutomation=$IgnoreAutomation ArduinoStatus=enabled"

try {
    $serial.Open()
    Start-Sleep -Milliseconds 1500
    $serial.DiscardInBuffer()
    Set-ArduinoStatus "idle"

    while ($true) {
        try {
            $line = $serial.ReadLine().Trim()
        }
        catch [TimeoutException] {
            continue
        }

        if ($line -notmatch "motion=([01])") {
            continue
        }

        $now = [DateTime]::UtcNow
        $motionDetected = $Matches[1] -eq "1"

        if ($motionDetected) {
            # Any motion resets the idle timer immediately. PIR modules often
            # hold this high for a few seconds, which is fine for this policy.
            $lastMotionAt = $now
        }

        if ($null -eq $lastMotionState -or $lastMotionState -ne $motionDetected) {
            $lastMotionState = $motionDetected
            if ($motionDetected) {
                Write-Host "Motion detected."
            }
            else {
                Write-Host "No motion detected. Idle timer started."
            }
        }

        if (-not $DryRun -and (($now - $lastAutomationPollAt).TotalMilliseconds -ge $AutomationPollIntervalMs)) {
            # Poll periodically rather than on every serial line. Motion modules
            # can emit quickly, and CLI state reads should stay cheap.
            $lastAutomationPollAt = $now
            $lastRuntimeState = Get-DisplayRuntimeState
        }

        $automationOwnsDisplay = $CooperateWithAutomation -and -not $IgnoreAutomation -and (Automation-OwnsDisplay -Automation $lastRuntimeState.Automation)

        if ($motionDetected) {
            if ($dimmedByBridge) {
                if ($automationOwnsDisplay) {
                    # If automation resumed while the bridge was dimmed, do not
                    # immediately fight it with a restore command.
                    Set-ArduinoStatus "standby"
                    if (($now - $lastStatusLogAt).TotalMilliseconds -ge 5000) {
                        Write-Host ("Motion detected, but Display Dimmer {0} automation is in control. Restore is standing by." -f $lastRuntimeState.Automation)
                        $lastStatusLogAt = $now
                    }
                    continue
                }

                $targetBrightness = $null
                if ($RestoreBrightness -ge 0) {
                    $targetBrightness = $RestoreBrightness
                }
                elseif ($null -ne $capturedRestoreBrightness) {
                    # Default behavior restores what Display Dimmer reported
                    # just before this bridge dimmed the display.
                    $targetBrightness = [int]$capturedRestoreBrightness
                }

                if ($null -eq $targetBrightness) {
                    Set-ArduinoStatus "active"
                    Write-Host "Motion detected. No restore brightness was available, so the bridge is leaving brightness unchanged."
                    $dimmedByBridge = $false
                    continue
                }

                $result = Send-BrightnessCommand -Brightness $targetBrightness
                Write-Host ("motion=1 restoreBrightness={0} exit={1} {2}" -f $targetBrightness, $result.ExitCode, $result.OutputText)

                if ($result.ExitCode -eq 0) {
                    $dimmedByBridge = $false
                    $capturedRestoreBrightness = $null
                    Clear-BufferedSerialInput
                    Set-ArduinoBrightness -Brightness $targetBrightness
                    Set-ArduinoStatus "active"
                }
                else {
                    Set-ArduinoStatus "error"
                }
            }
            else {
                Set-ArduinoStatus "active"
            }

            continue
        }

        $idleForSeconds = [int][Math]::Floor(($now - $lastMotionAt).TotalSeconds)
        $secondsRemaining = [Math]::Max(0, $idleDurationSeconds - $idleForSeconds)

        if ($idleForSeconds -lt $idleDurationSeconds) {
            Set-ArduinoStatus "active"
            if (($now - $lastStatusLogAt).TotalMilliseconds -ge 10000) {
                Write-Host ("motion=0 idleFor={0}s dimIn={1}s" -f $idleForSeconds, $secondsRemaining)
                $lastStatusLogAt = $now
            }
            continue
        }

        if ($dimmedByBridge) {
            Set-ArduinoStatus "dimmed"
            if (($now - $lastStatusLogAt).TotalMilliseconds -ge 30000) {
                Write-Host ("motion=0 idleFor={0}s already-dimmed brightness={1}" -f $idleForSeconds, $DimBrightness)
                $lastStatusLogAt = $now
            }
            continue
        }

        if ($automationOwnsDisplay) {
            # Cooperative mode stands by instead of turning a schedule/app rule
            # into an interrupted manual override.
            Set-ArduinoStatus "standby"
            if (($now - $lastStatusLogAt).TotalMilliseconds -ge 5000) {
                Write-Host ("motion=0 idleFor={0}s Display Dimmer {1} automation is in control. Dim command is standing by." -f $idleForSeconds, $lastRuntimeState.Automation)
                $lastStatusLogAt = $now
            }
            continue
        }

        if ($null -ne $lastRuntimeState.Brightness) {
            # Capture the live value as late as possible so restore matches what
            # the app actually had before the idle dim.
            $capturedRestoreBrightness = [int]$lastRuntimeState.Brightness
        }

        $result = Send-BrightnessCommand -Brightness $DimBrightness
        Write-Host ("motion=0 idleFor={0}s dimBrightness={1} restoreBrightness={2} exit={3} {4}" -f $idleForSeconds, $DimBrightness, $capturedRestoreBrightness, $result.ExitCode, $result.OutputText)

        if ($result.ExitCode -eq 0) {
            $dimmedByBridge = $true
            Clear-BufferedSerialInput
            Set-ArduinoBrightness -Brightness $DimBrightness
            Set-ArduinoStatus "dimmed"
        }
        else {
            Set-ArduinoStatus "error"
        }
    }
}
finally {
    if ($serial -ne $null) {
        Set-ArduinoStatus "idle"

        try {
            if ($serial.IsOpen) {
                $serial.Close()
            }
        }
        catch {
        }

        try {
            $serial.Dispose()
        }
        catch {
        }
    }
}
