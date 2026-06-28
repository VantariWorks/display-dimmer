param(
    # Serial port used by the Arduino, for example COM3 or COM7.
    [string]$Port = "COM3",

    # Display Dimmer target id to control. Prefer a stable dd_... id from --list-displays.
    [string]$Target,

    # Arduino serial speed. Must match Serial.begin(...) in the sketch.
    [int]$BaudRate = 9600,

    # Raw analog reading treated as the darkest useful room reading.
    [int]$RawDark = 10,

    # Raw analog reading treated as the brightest useful room reading.
    [int]$RawBright = 760,

    # Lowest brightness percentage the bridge will send.
    [int]$MinBrightness = 20,

    # Highest brightness percentage the bridge will send.
    [int]$MaxBrightness = 80,

    # Rounds brightness to this step size to reduce noisy updates.
    [int]$BrightnessStep = 2,

    # Minimum sensor-driven brightness change required before sending a command.
    [int]$ChangeThreshold = 5,

    # Minimum live-vs-last-sent difference required before reasserting sensor control.
    [int]$ReassertThreshold = 1,

    # Minimum delay between applying brightness commands.
    [int]$MinSendIntervalMs = 200,

    # How often the bridge polls Display Dimmer for schedule/app-rule ownership.
    [int]$AutomationPollIntervalMs = 500,

    # Print readings and intended commands without changing brightness.
    [switch]$DryRun,

    # Keep sending sensor brightness even while schedules/app rules are active.
    [switch]$IgnoreAutomationResume,

    # Pause the sensor when Display Dimmer brightness changes outside this bridge.
    [switch]$PauseOnManualChange,

    # If greater than zero, resume sensor control after this many seconds of manual pause.
    [int]$ManualPauseSeconds = 0,

    # Disable LED/status messages sent back to the Arduino.
    [switch]$DisableArduinoStatus,

    # Source label sent to Display Dimmer so automation handoff can identify this bridge.
    [string]$Source = "arduino-sensor",

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

function Assert-ValidParameters {
    if ([string]::IsNullOrWhiteSpace($Port)) {
        throw "Port is required, for example COM3 or COM7."
    }

    if ([string]::IsNullOrWhiteSpace($Target)) {
        throw "Target is required. Run DisplayDimmer.Cli.exe --list-displays and pass a stable dd_... ID, or pass primary for a quick primary-display test."
    }

    if ($BaudRate -le 0) {
        throw "BaudRate must be greater than 0."
    }

    if ($RawDark -lt 0 -or $RawDark -gt 1023 -or $RawBright -lt 0 -or $RawBright -gt 1023) {
        throw "RawDark and RawBright must be Arduino analog values from 0 to 1023."
    }

    if ($RawDark -eq $RawBright) {
        throw "RawDark and RawBright must be different values. Inverted sensors are supported, but the span cannot be zero."
    }

    if ($MinBrightness -lt 0 -or $MinBrightness -gt 100 -or $MaxBrightness -lt 0 -or $MaxBrightness -gt 100) {
        throw "MinBrightness and MaxBrightness must be from 0 to 100."
    }

    if ($MinBrightness -gt $MaxBrightness) {
        throw "MinBrightness cannot be greater than MaxBrightness."
    }

    if ($BrightnessStep -le 0 -or $BrightnessStep -gt 100) {
        throw "BrightnessStep must be from 1 to 100."
    }

    if ($ChangeThreshold -lt 0 -or $ReassertThreshold -lt 0) {
        throw "ChangeThreshold and ReassertThreshold cannot be negative."
    }

    if ($MinSendIntervalMs -lt 0 -or $AutomationPollIntervalMs -le 0) {
        throw "MinSendIntervalMs cannot be negative and AutomationPollIntervalMs must be greater than 0."
    }

    if ($ManualPauseSeconds -lt 0) {
        throw "ManualPauseSeconds cannot be negative."
    }
}

function Convert-RawToBrightness {
    param([double]$Raw)

    # Calibrate the Arduino's raw analog range into Display Dimmer's brightness
    # range. RawBright can be lower than RawDark for inverted sensor modules.
    $dark = [double]$RawDark
    $bright = [double]$RawBright
    $span = $bright - $dark

    $ratio = ([double]$Raw - $dark) / $span
    $ratio = [Math]::Max(0.0, [Math]::Min(1.0, $ratio))
    $mapped = [double]$MinBrightness + ($ratio * ([double]$MaxBrightness - [double]$MinBrightness))

    $rounded = [int][Math]::Round($mapped)

    if ($BrightnessStep -gt 1) {
        $rounded = [int]([Math]::Round([double]$rounded / [double]$BrightnessStep) * [double]$BrightnessStep)
    }

    return Clamp-Int -Value $rounded -Min $MinBrightness -Max $MaxBrightness
}

function New-DisplayRuntimeState {
    param(
        [string]$Automation = "unknown",
        $Brightness = $null,
        [string[]]$ApplyTargets = @(),
        [string[]]$StandbyTargets = @()
    )

    [pscustomobject]@{
        Automation = $Automation
        Brightness = $Brightness
        ApplyTargets = @($ApplyTargets)
        StandbyTargets = @($StandbyTargets)
    }
}

function Test-DisplayMatchesTarget {
    param($Display)

    if ($null -eq $Display) {
        return $false
    }

    if ([string]::IsNullOrWhiteSpace($Target)) {
        return $false
    }

    $targetText = $Target.Trim()
    if ($targetText -eq "all") {
        return $true
    }

    if ($targetText -eq "primary") {
        try {
            return $Display.isPrimary -eq $true
        }
        catch {
            return $false
        }
    }

    $candidateFields = @("targetId", "id", "sessionId", "identity", "deviceName")
    foreach ($field in $candidateFields) {
        try {
            $property = $Display.PSObject.Properties[$field]
            if ($null -eq $property) {
                continue
            }

            $value = $property.Value
            if ($null -ne $value -and $targetText -eq ([string]$value).Trim()) {
                return $true
            }
        }
        catch {
        }
    }

    return $false
}

function Get-DisplayCommandTarget {
    param($Display)

    if ($null -eq $Display) {
        return $null
    }

    $candidateFields = @("targetId", "id", "sessionId", "identity", "deviceName")
    foreach ($field in $candidateFields) {
        try {
            $property = $Display.PSObject.Properties[$field]
            if ($null -eq $property) {
                continue
            }

            $value = $property.Value
            if ($null -ne $value -and -not [string]::IsNullOrWhiteSpace([string]$value)) {
                return ([string]$value).Trim()
            }
        }
        catch {
        }
    }

    return $null
}

function Join-TargetList {
    param([string[]]$Targets)

    $items = @()
    foreach ($targetItem in @($Targets)) {
        if (-not [string]::IsNullOrWhiteSpace($targetItem)) {
            $items += $targetItem.Trim()
        }
    }

    if ($items.Count -eq 0) {
        return ""
    }

    return ($items -join ",")
}

function Select-DisplaysForTarget {
    param($State)

    if ($null -eq $State -or $null -eq $State.displays) {
        return @()
    }

    $allDisplays = @($State.displays)
    if ([string]::IsNullOrWhiteSpace($Target) -or $Target.Trim() -eq "all") {
        return $allDisplays
    }

    $matched = @()
    foreach ($display in $allDisplays) {
        if (Test-DisplayMatchesTarget -Display $display) {
            $matched += $display
        }
    }

    if ($matched.Count -gt 0) {
        return $matched
    }

    # Current API returns one display for --target primary after resolving it.
    # Keep that path working, but do not silently consume unrelated displays if
    # a future response shape ever returns a broader list.
    if ($Target.Trim() -eq "primary" -and $allDisplays.Count -eq 1) {
        return $allDisplays
    }

    if ($allDisplays.Count -eq 1) {
        return $allDisplays
    }

    return @()
}

function Get-DisplayRuntimeState {
    try {
        # Poll the running app instead of guessing. This lets the bridge stand
        # down when schedules or app rules legitimately own the display.
        if ($DryRun) {
            return New-DisplayRuntimeState -Automation "none" -ApplyTargets @($Target)
        }

        if (-not (Test-CliAvailable -Path $CliPath)) {
            return New-DisplayRuntimeState -Automation "unknown" -ApplyTargets @($Target)
        }

        $stateOutput = & $CliPath --get-state --target $Target --json
        if ($LASTEXITCODE -ne 0) {
            return New-DisplayRuntimeState -Automation "unknown" -ApplyTargets @($Target)
        }

        $stateText = ($stateOutput -join "").Trim()
        if ([string]::IsNullOrWhiteSpace($stateText)) {
            return New-DisplayRuntimeState -Automation "unknown" -ApplyTargets @($Target)
        }

        $state = $stateText | ConvertFrom-Json
        if ($null -eq $state -or $null -eq $state.displays) {
            return New-DisplayRuntimeState -Automation "unknown" -ApplyTargets @($Target)
        }

        $targetDisplays = Select-DisplaysForTarget -State $state
        if ($targetDisplays.Count -eq 0) {
            return New-DisplayRuntimeState -Automation "unknown" -ApplyTargets @($Target)
        }

        $applyTargets = @()
        $standbyTargets = @()
        $perAppTakingControl = $false
        $scheduleTakingControl = $false
        $automationInterrupted = $false
        $firstBrightness = $null
        $applyBrightness = $null
        $standbyBrightness = $null

        foreach ($display in $targetDisplays) {
            $displayBrightness = $null
            if ($null -ne $display.brightness) {
                $displayBrightness = [int]$display.brightness
                if ($null -eq $firstBrightness) {
                    $firstBrightness = $displayBrightness
                }
            }

            $commandTarget = Get-DisplayCommandTarget -Display $display
            if ([string]::IsNullOrWhiteSpace($commandTarget)) {
                continue
            }

            $perAppOwnsDisplay = $display.perAppActive -eq $true -and $display.perAppInterrupted -ne $true
            $scheduleOwnsDisplay = $display.scheduleActive -eq $true -and $display.scheduleInterrupted -ne $true

            if ($perAppOwnsDisplay -or $scheduleOwnsDisplay) {
                $standbyTargets += $commandTarget
                if ($null -eq $standbyBrightness -and $null -ne $displayBrightness) {
                    $standbyBrightness = $displayBrightness
                }

                if ($perAppOwnsDisplay) {
                    $perAppTakingControl = $true
                }
                elseif ($scheduleOwnsDisplay) {
                    $scheduleTakingControl = $true
                }
            }
            else {
                $applyTargets += $commandTarget
                if ($null -eq $applyBrightness -and $null -ne $displayBrightness) {
                    $applyBrightness = $displayBrightness
                }
            }

            if ($display.perAppInterrupted -eq $true) {
                $automationInterrupted = $true
            }

            if ($display.scheduleActive -eq $true -and $display.scheduleInterrupted -eq $true) {
                $automationInterrupted = $true
            }
        }

        if (($applyTargets.Count + $standbyTargets.Count) -eq 0) {
            return New-DisplayRuntimeState -Automation "unknown" -Brightness $firstBrightness -ApplyTargets @($Target)
        }

        $liveBrightness = $applyBrightness
        if ($null -eq $liveBrightness) {
            $liveBrightness = $standbyBrightness
        }
        if ($null -eq $liveBrightness) {
            $liveBrightness = $firstBrightness
        }

        if ($perAppTakingControl) {
            $automation = if ($applyTargets.Count -gt 0) { "partial-app-rule" } else { "app-rule" }
            return New-DisplayRuntimeState -Automation $automation -Brightness $liveBrightness -ApplyTargets $applyTargets -StandbyTargets $standbyTargets
        }

        if ($scheduleTakingControl) {
            $automation = if ($applyTargets.Count -gt 0) { "partial-schedule" } else { "schedule" }
            return New-DisplayRuntimeState -Automation $automation -Brightness $liveBrightness -ApplyTargets $applyTargets -StandbyTargets $standbyTargets
        }

        if ($automationInterrupted) {
            return New-DisplayRuntimeState -Automation "manual-override" -Brightness $liveBrightness -ApplyTargets $applyTargets
        }

        return New-DisplayRuntimeState -Automation "none" -Brightness $liveBrightness -ApplyTargets $applyTargets
    }
    catch {
        return New-DisplayRuntimeState -Automation "unknown" -ApplyTargets @($Target)
    }
}

$lastArduinoStatus = $null

function Set-ArduinoStatus {
    param([string]$Status)

    # Status messages are only for the Arduino LED demo. They are intentionally
    # best-effort so a serial hiccup cannot stop brightness control.
    if ($DisableArduinoStatus) {
        return
    }

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

function Format-CliOutputText {
    param([object[]]$Output)

    $text = (($Output | ForEach-Object { $_.ToString() }) -join " ").Trim()
    if ([string]::IsNullOrWhiteSpace($text)) {
        return ""
    }

    try {
        $parsed = $text | ConvertFrom-Json
        if ($null -ne $parsed) {
            $message = ""
            if ($null -ne $parsed.message) {
                $message = [string]$parsed.message
            }

            if ($null -ne $parsed.errorCode -and -not [string]::IsNullOrWhiteSpace([string]$parsed.errorCode)) {
                if (-not [string]::IsNullOrWhiteSpace($message)) {
                    return (([string]$parsed.errorCode) + ": " + $message)
                }

                return [string]$parsed.errorCode
            }

            if (-not [string]::IsNullOrWhiteSpace($message)) {
                return $message
            }
        }
    }
    catch {
    }

    return $text
}

function Should-LogCliResult {
    param(
        [int]$ExitCode,
        [string]$OutputText,
        [DateTime]$Now
    )

    if ($ExitCode -eq 0) {
        $script:lastCliFailureSignature = $null
        $script:lastCliFailureLogAt = [DateTime]::MinValue
        return $true
    }

    $outputSignatureText = if ($null -ne $OutputText) { $OutputText } else { "" }
    $signature = ([string]$ExitCode) + "|" + $outputSignatureText
    if ($script:lastCliFailureSignature -ne $signature -or (($Now - $script:lastCliFailureLogAt).TotalMilliseconds -ge 5000)) {
        $script:lastCliFailureSignature = $signature
        $script:lastCliFailureLogAt = $Now
        return $true
    }

    return $false
}

function Write-SendIntervalGuidance {
    if ($MinSendIntervalMs -lt 75) {
        Write-Warning "MinSendIntervalMs=$MinSendIntervalMs is very aggressive. Software/gamma dimming may tolerate 100-150 ms, but lower intervals can spam logs and DDC/CI displays can lag, timeout, or ignore rapid writes."
        return
    }

    if ($MinSendIntervalMs -lt 150) {
        Write-Host "IntervalMs=$MinSendIntervalMs is tuned for software/gamma responsiveness. If the target uses DDC/CI and brightness lags or commands fail, try 250-500 ms."
        return
    }

    if ($MinSendIntervalMs -lt 200) {
        Write-Host "IntervalMs=$MinSendIntervalMs is responsive. Software/gamma dimming should handle this well; DDC/CI monitors vary, so use 250-500 ms if writes lag or timeout."
    }
}

function Send-BrightnessCommand {
    param(
        [int]$Brightness,
        [switch]$UpdateOnly,
        [string[]]$Targets = @()
    )

    # --set-brightness applies now. --update-external-brightness only refreshes
    # the app's pending sensor intent while Display Dimmer automation is active.
    if ($DryRun) {
        return [pscustomobject]@{
            ExitCode = 0
            OutputText = "dry-run"
        }
    }

    $commandName = if ($UpdateOnly) { "--update-external-brightness" } else { "--set-brightness" }
    $resolvedTargets = @()
    foreach ($targetItem in @($Targets)) {
        if (-not [string]::IsNullOrWhiteSpace($targetItem)) {
            $resolvedTargets += $targetItem.Trim()
        }
    }

    if ($resolvedTargets.Count -eq 0) {
        $resolvedTargets = @($Target)
    }

    $cliArgs = @($commandName, $Brightness)
    foreach ($targetItem in $resolvedTargets) {
        $cliArgs += @("--target", $targetItem)
    }
    $cliArgs += "--json"
    if (-not [string]::IsNullOrWhiteSpace($Source)) {
        $cliArgs += @("--source", $Source)
    }

    $output = & $CliPath @cliArgs
    $exitCode = $LASTEXITCODE
    $outputText = Format-CliOutputText -Output $output

    [pscustomobject]@{
        ExitCode = $exitCode
        OutputText = $outputText
    }
}

$CliPath = Resolve-CliPath -ProvidedPath $CliPath
Assert-ValidParameters

if (-not $DryRun -and -not (Test-CliAvailable -Path $CliPath)) {
    throw "DisplayDimmer.Cli.exe was not found at: $CliPath"
}

$serial = New-Object System.IO.Ports.SerialPort $Port, $BaudRate, "None", 8, "One"
$serial.ReadTimeout = 1000
$serial.NewLine = "`n"

$lastSentBrightness = $null
$lastSentAt = [DateTime]::MinValue
$lastAutomationPollAt = [DateTime]::MinValue
$lastExternalUpdateAt = [DateTime]::MinValue
$lastExternalUpdateBrightness = $null
$lastStandbyLogAt = [DateTime]::MinValue
$lastManualPauseLogAt = [DateTime]::MinValue
$lastObservedLiveBrightness = $null
$smoothedRaw = $null
$hasSentBrightness = $false
$standbyForAutomation = $false
$standbyReason = "none"
$manualPauseActive = $false
$manualPauseUntil = [DateTime]::MinValue
$forceSendAfterStandby = $false
$currentApplyTargets = @($Target)
$currentStandbyTargets = @()
$standbyTargetSignature = ""

Write-Host "Opening $Port at $BaudRate baud."
Write-Host "Target=$Target RawDark=$RawDark RawBright=$RawBright Brightness=$MinBrightness-$MaxBrightness Step=$BrightnessStep Threshold=$ChangeThreshold ReassertThreshold=$ReassertThreshold IntervalMs=$MinSendIntervalMs AutomationPollMs=$AutomationPollIntervalMs Source=$Source DryRun=$DryRun IgnoreAutomationResume=$IgnoreAutomationResume PauseOnManualChange=$PauseOnManualChange ManualPauseSeconds=$ManualPauseSeconds DisableArduinoStatus=$DisableArduinoStatus"
Write-SendIntervalGuidance

try {
    try {
        $serial.Open()
    }
    catch [System.UnauthorizedAccessException] {
        throw "Could not open $Port because Windows denied access. Close Arduino Serial Monitor, Serial Plotter, VS Code/PlatformIO serial monitors, or any other bridge/script using the same COM port, then unplug/replug the Arduino if the port stays locked."
    }
    catch {
        throw "Could not open $Port. Confirm the Arduino is connected, the COM port is correct, and no other program is using it. $($_.Exception.Message)"
    }

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

        if ($line -notmatch "raw=(\d+)") {
            continue
        }

        $raw = [int]$Matches[1]
        if ($null -eq $smoothedRaw) {
            $smoothedRaw = [double]$raw
        }
        else {
            $smoothedRaw = ($smoothedRaw * 0.80) + ([double]$raw * 0.20)
        }

        $brightness = Convert-RawToBrightness -Raw $smoothedRaw
        $now = [DateTime]::UtcNow

        if (-not $DryRun) {
            # Poll the app periodically so each selected display can either stay
            # under sensor control or stand by for its own schedule/app rule.
            $shouldPollAutomation = (($now - $lastAutomationPollAt).TotalMilliseconds -ge $AutomationPollIntervalMs)
            if ($shouldPollAutomation) {
                $lastAutomationPollAt = $now
                $runtimeState = Get-DisplayRuntimeState
                $automationState = $runtimeState.Automation
                $currentApplyTargets = @($runtimeState.ApplyTargets)
                $currentStandbyTargets = @($runtimeState.StandbyTargets)

                if ($IgnoreAutomationResume) {
                    $automationState = "none"
                    $currentApplyTargets = @($Target)
                    $currentStandbyTargets = @()
                }
                elseif ($currentApplyTargets.Count -eq 0 -and $currentStandbyTargets.Count -eq 0) {
                    $currentApplyTargets = @($Target)
                }

                if ($null -ne $runtimeState.Brightness) {
                    $lastObservedLiveBrightness = [int]$runtimeState.Brightness
                }

                $hasAutomationStandbyTargets = -not $IgnoreAutomationResume -and $currentStandbyTargets.Count -gt 0
                $newStandbyTargetSignature = Join-TargetList -Targets $currentStandbyTargets

                if ($hasAutomationStandbyTargets) {
                    if (-not $standbyForAutomation -or $standbyReason -ne $automationState -or $standbyTargetSignature -ne $newStandbyTargetSignature) {
                        # Do not fight schedules/app rules. Stand by only for
                        # displays they own; keep controlling the remaining targets.
                        $standbyForAutomation = $true
                        $standbyReason = $automationState
                        $standbyTargetSignature = $newStandbyTargetSignature
                        $lastExternalUpdateAt = [DateTime]::MinValue
                        if ($currentApplyTargets.Count -gt 0) {
                            $forceSendAfterStandby = $true
                            $lastSentAt = [DateTime]::MinValue
                            Set-ArduinoStatus "active"
                            Write-Host ("Display Dimmer {0} automation owns {1} target(s). Sensor bridge is standing by for those and controlling {2} target(s)." -f $automationState, $currentStandbyTargets.Count, $currentApplyTargets.Count)
                        }
                        else {
                            Set-ArduinoStatus "standby"
                            Write-Host "Display Dimmer $automationState automation is in control. Sensor bridge is standing by."
                        }
                    }
                }
                elseif (-not $IgnoreAutomationResume -and $automationState -eq "manual-override") {
                    if ($standbyForAutomation) {
                        $standbyForAutomation = $false
                        $standbyReason = "none"
                        $standbyTargetSignature = ""
                        $lastExternalUpdateAt = [DateTime]::MinValue

                        if ($PauseOnManualChange) {
                            $manualPauseActive = $true
                            if ($ManualPauseSeconds -gt 0) {
                                $manualPauseUntil = $now.AddSeconds($ManualPauseSeconds)
                            }
                            else {
                                $manualPauseUntil = [DateTime]::MaxValue
                            }

                            Set-ArduinoStatus "standby"
                            Write-Host "Display Dimmer automation was manually interrupted. Sensor bridge is paused."
                        }
                        else {
                            $forceSendAfterStandby = $true
                            $lastSentBrightness = $null
                            $lastSentAt = [DateTime]::MinValue
                            $lastObservedLiveBrightness = $null
                            Set-ArduinoStatus "active"
                            Write-Host "Display Dimmer automation was interrupted. Sensor bridge is taking control again."
                        }
                    }
                }
                elseif (-not $IgnoreAutomationResume -and $automationState -eq "none") {
                    if ($standbyForAutomation) {
                        $standbyForAutomation = $false
                        $standbyReason = "none"
                        $standbyTargetSignature = ""
                        $forceSendAfterStandby = $true
                        $lastSentBrightness = $null
                        $lastSentAt = [DateTime]::MinValue
                        $lastObservedLiveBrightness = $null
                        $manualPauseActive = $false
                        Set-ArduinoStatus "active"
                        Write-Host "Display Dimmer automation ended. Sensor bridge is taking control again."
                    }
                }
            }
        }

        if (-not $IgnoreAutomationResume -and $currentStandbyTargets.Count -gt 0) {
            # While automation owns a display, keep a fresh non-applying value
            # for that display only. Other selected displays can keep following
            # the sensor normally.
            $shouldUpdateExternalIntent =
                $null -eq $lastExternalUpdateBrightness -or
                [Math]::Abs($brightness - $lastExternalUpdateBrightness) -ge $ChangeThreshold -or
                (($now - $lastExternalUpdateAt).TotalMilliseconds -ge $AutomationPollIntervalMs)

            if ($shouldUpdateExternalIntent) {
                $result = Send-BrightnessCommand -Brightness $brightness -UpdateOnly -Targets $currentStandbyTargets
                if ($result.ExitCode -eq 0) {
                    $lastExternalUpdateBrightness = $brightness
                    $lastExternalUpdateAt = $now
                    if ($currentApplyTargets.Count -eq 0) {
                        Set-ArduinoStatus "standby"
                    }
                }
                else {
                    Set-ArduinoStatus "error"
                }

                if (Should-LogCliResult -ExitCode $result.ExitCode -OutputText $result.OutputText -Now $now) {
                    Write-Host ("raw={0} smooth={1:N0} brightness={2} standby={3} standbyTargets={4} update-external exit={5} {6}" -f $raw, $smoothedRaw, $brightness, $standbyReason, (Join-TargetList -Targets $currentStandbyTargets), $result.ExitCode, $result.OutputText)
                }

                if ($currentApplyTargets.Count -eq 0) {
                    continue
                }
            }

            if ($currentApplyTargets.Count -eq 0 -and ($now - $lastStandbyLogAt).TotalMilliseconds -ge 5000) {
                Write-Host ("raw={0} smooth={1:N0} brightness={2} standby={3} standbyTargets={4}" -f $raw, $smoothedRaw, $brightness, $standbyReason, (Join-TargetList -Targets $currentStandbyTargets))
                $lastStandbyLogAt = $now
            }

            if ($currentApplyTargets.Count -eq 0) {
                continue
            }
        }

        if ($manualPauseActive) {
            # Manual pause means manual control intentionally beat the sensor. The
            # bridge keeps reading serial input but does not send brightness.
            if ($ManualPauseSeconds -gt 0 -and $now -ge $manualPauseUntil) {
                $manualPauseActive = $false
                $manualPauseUntil = [DateTime]::MinValue
                $forceSendAfterStandby = $true
                $lastSentBrightness = $null
                $lastSentAt = [DateTime]::MinValue
                $lastObservedLiveBrightness = $null
                Set-ArduinoStatus "active"
                Write-Host "Manual brightness pause ended. Sensor bridge is taking control again."
            }
            else {
                if (($now - $lastManualPauseLogAt).TotalMilliseconds -ge 5000) {
                    if ($ManualPauseSeconds -gt 0) {
                        $secondsLeft = [Math]::Max(0, [int][Math]::Ceiling(($manualPauseUntil - $now).TotalSeconds))
                        Write-Host ("raw={0} smooth={1:N0} brightness={2} manual-pause secondsLeft={3}" -f $raw, $smoothedRaw, $brightness, $secondsLeft)
                    }
                    else {
                        Write-Host ("raw={0} smooth={1:N0} brightness={2} manual-pause" -f $raw, $smoothedRaw, $brightness)
                    }
                    $lastManualPauseLogAt = $now
                }
                continue
            }
        }

        $enoughChange = $null -eq $lastSentBrightness -or [Math]::Abs($brightness - $lastSentBrightness) -ge $ChangeThreshold
        $enoughTime = (($now - $lastSentAt).TotalMilliseconds -ge $MinSendIntervalMs)
        $liveDiffersFromLastSent = $false
        if ($null -ne $lastObservedLiveBrightness -and $null -ne $lastSentBrightness) {
            $liveDiffersFromLastSent = [Math]::Abs([int]$lastObservedLiveBrightness - [int]$lastSentBrightness) -ge $ReassertThreshold
        }

        $shouldReassert = $false
        if ($liveDiffersFromLastSent -and $null -ne $lastObservedLiveBrightness) {
            $shouldReassert = [Math]::Abs($brightness - [int]$lastObservedLiveBrightness) -ge $ReassertThreshold
        }

        # Compare live brightness to the last value this bridge actually
        # applied. Comparing against the current sensor target would mistake
        # normal sensor movement for a manual slider change.
        if ($PauseOnManualChange -and $liveDiffersFromLastSent) {
            $manualPauseActive = $true
            if ($ManualPauseSeconds -gt 0) {
                $manualPauseUntil = $now.AddSeconds($ManualPauseSeconds)
            }
            else {
                $manualPauseUntil = [DateTime]::MaxValue
            }

            Set-ArduinoStatus "standby"
            Write-Host ("Manual brightness change detected. Sensor bridge is paused. raw={0} smooth={1:N0} sensorBrightness={2} lastSent={3} liveBrightness={4}" -f $raw, $smoothedRaw, $brightness, $lastSentBrightness, $lastObservedLiveBrightness)
            continue
        }

        $shouldSendBrightness = $forceSendAfterStandby -or (($enoughChange -or $shouldReassert) -and $enoughTime)

        if (-not $shouldSendBrightness) {
            # The current sensor value is close enough to the last applied value.
            Write-Host ("raw={0} smooth={1:N0} brightness={2} skipped" -f $raw, $smoothedRaw, $brightness)
            continue
        }

        if ($DryRun) {
            Set-ArduinoStatus "active"
            Write-Host ("raw={0} smooth={1:N0} brightness={2} dry-run" -f $raw, $smoothedRaw, $brightness)
            $hasSentBrightness = $true
            $lastObservedLiveBrightness = $brightness
            $lastSentBrightness = $brightness
            $lastSentAt = $now
        }
        else {
            if (-not $IgnoreAutomationResume) {
                try {
                    # Close the race where a schedule/app rule takes control
                    # after the normal poll but before this applying command.
                    $previousStandbySignature = Join-TargetList -Targets $currentStandbyTargets
                    $runtimeState = Get-DisplayRuntimeState
                    if ($null -ne $runtimeState) {
                        $lastAutomationPollAt = $now
                        $currentApplyTargets = @($runtimeState.ApplyTargets)
                        $currentStandbyTargets = @($runtimeState.StandbyTargets)

                        if ($currentApplyTargets.Count -eq 0 -and $currentStandbyTargets.Count -eq 0) {
                            $currentApplyTargets = @($Target)
                        }

                        if ($null -ne $runtimeState.Brightness) {
                            $lastObservedLiveBrightness = [int]$runtimeState.Brightness
                        }

                        if ($currentStandbyTargets.Count -gt 0) {
                            $newStandbySignature = Join-TargetList -Targets $currentStandbyTargets
                            $standbyForAutomation = $true
                            $standbyReason = $runtimeState.Automation
                            $standbyTargetSignature = $newStandbySignature

                            $shouldRefreshExternalIntent =
                                $previousStandbySignature -ne $newStandbySignature -or
                                $null -eq $lastExternalUpdateBrightness -or
                                [Math]::Abs($brightness - $lastExternalUpdateBrightness) -ge $ChangeThreshold -or
                                (($now - $lastExternalUpdateAt).TotalMilliseconds -ge $AutomationPollIntervalMs)

                            if ($shouldRefreshExternalIntent) {
                                $standbyResult = Send-BrightnessCommand -Brightness $brightness -UpdateOnly -Targets $currentStandbyTargets
                                $standbyCompletedAt = [DateTime]::UtcNow
                                if ($standbyResult.ExitCode -eq 0) {
                                    $lastExternalUpdateBrightness = $brightness
                                    $lastExternalUpdateAt = $standbyCompletedAt
                                    if ($currentApplyTargets.Count -eq 0) {
                                        Set-ArduinoStatus "standby"
                                    }
                                }
                                else {
                                    Set-ArduinoStatus "error"
                                }

                                if (Should-LogCliResult -ExitCode $standbyResult.ExitCode -OutputText $standbyResult.OutputText -Now $standbyCompletedAt) {
                                    Write-Host ("raw={0} smooth={1:N0} brightness={2} standby={3} standbyTargets={4} update-external-before-apply exit={5} {6}" -f $raw, $smoothedRaw, $brightness, $standbyReason, (Join-TargetList -Targets $currentStandbyTargets), $standbyResult.ExitCode, $standbyResult.OutputText)
                                }
                            }

                            if ($currentApplyTargets.Count -eq 0) {
                                $forceSendAfterStandby = $false
                                continue
                            }
                        }
                    }
                }
                catch {
                }
            }

            $sendTargets = @($currentApplyTargets)
            if ($sendTargets.Count -eq 0) {
                $sendTargets = @($Target)
            }

            $result = Send-BrightnessCommand -Brightness $brightness -Targets $sendTargets
            $completedAt = [DateTime]::UtcNow
            $reason = if ($forceSendAfterStandby) { "resume" } elseif ($shouldReassert) { "reassert" } else { "sensor" }
            if (Should-LogCliResult -ExitCode $result.ExitCode -OutputText $result.OutputText -Now $completedAt) {
                Write-Host ("raw={0} smooth={1:N0} brightness={2} reason={3} targets={4} exit={5} {6}" -f $raw, $smoothedRaw, $brightness, $reason, (Join-TargetList -Targets $sendTargets), $result.ExitCode, $result.OutputText)
            }
            if ($result.ExitCode -eq 0) {
                $hasSentBrightness = $true
                $lastObservedLiveBrightness = $brightness
                $lastSentBrightness = $brightness
                $lastSentAt = $completedAt
                Set-ArduinoStatus "active"
            }
            else {
                $lastSentAt = $completedAt
                Set-ArduinoStatus "error"
            }
        }

        $forceSendAfterStandby = $false
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

