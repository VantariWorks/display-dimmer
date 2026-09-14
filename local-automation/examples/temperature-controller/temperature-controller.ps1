# Windows PowerShell 5.1 or PowerShell 7; no external modules.
# Deliberately changes live temperature, then releases its own source.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Target,
    [ValidateRange(2500, 8300)]
    [int]$Kelvin = 4000,
    [ValidateRange(1, 86400)]
    [int]$DurationSeconds = 60,
    [ValidateNotNullOrEmpty()]
    [string]$Source = 'temperature-example',
    [ValidateNotNullOrEmpty()]
    [string]$CliPath = 'DisplayDimmer.Cli.exe'
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($Source) -or $Source.Trim() -eq 'cli') {
    throw 'Choose a nonblank named cooperative source, not cli.'
}
$Source = $Source.Trim()

function Invoke-Dimmer {
    param([string[]]$CommandArguments)

    $output = & $CliPath @CommandArguments --json
    $commandExitCode = $LASTEXITCODE
    $response = ($output -join [Environment]::NewLine) | ConvertFrom-Json
    if ($commandExitCode -ne 0 -or $null -eq $response -or -not $response.success) {
        throw "Display Dimmer command failed (exit $commandExitCode): $($response.errorCode) $($response.message)"
    }
    return $response
}

function Assert-TemperatureCapabilities {
    param($Response)

    foreach ($requiredCapability in @('temperature', 'temperature-kelvin', 'external-temperature')) {
        if (@($Response.capabilities) -notcontains $requiredCapability) {
            throw "The running app does not advertise $requiredCapability. Update/restart Display Dimmer and use its matching CLI."
        }
    }
}

$touchedTargets = @{}
$runClock = [Diagnostics.Stopwatch]::StartNew()
try {
    while ($runClock.Elapsed.TotalSeconds -lt $DurationSeconds) {
        $state = Invoke-Dimmer -CommandArguments @('--get-state', '--target', $Target)
        Assert-TemperatureCapabilities -Response $state
        foreach ($display in @($state.displays)) {
            if ($display.temperatureAvailable -ne $true) { continue }
            if ([string]::IsNullOrWhiteSpace($display.targetId)) {
                throw 'A display is missing targetId; stop rather than guess a Windows display number.'
            }
            if (@('manual', 'perApp', 'schedule', 'external', 'session', 'saved') -notcontains $display.temperatureOwner) {
                throw 'Missing or unknown temperature ownership; do not infer it from brightness rules.'
            }

            $command = '--set-temperature'
            if (@('manual', 'perApp', 'schedule') -contains $display.temperatureOwner) {
                $command = '--update-external-temperature'
            }
            # IPC failure can occur after an accepted write; remember before invoking.
            $physicalTarget = [string]$display.targetId
            $touchedTargets[$physicalTarget] = $true
            $response = Invoke-Dimmer -CommandArguments @(
                $command, $Kelvin.ToString([Globalization.CultureInfo]::InvariantCulture),
                '--temperature-unit', 'kelvin', '--target', $physicalTarget, '--source', $Source
            )
            foreach ($result in @($response.results)) {
                if (-not $result.success) {
                    throw "Temperature failed for $($result.targetId): $($result.errorCode) $($result.message)"
                }
                Write-Verbose "$($result.targetId): $($result.temperatureDisposition), effective approximately $($result.effectiveApproximateTemperatureKelvin) K"
            }
        }
        Start-Sleep -Milliseconds 1000
    }
}
finally {
    $runClock.Stop()
    foreach ($physicalTarget in @($touchedTargets.Keys)) {
        try {
            $null = Invoke-Dimmer -CommandArguments @('--resume-temperature', '--target', $physicalTarget, '--source', $Source)
        }
        catch {
            Write-Warning "Could not release source '$Source' on '$physicalTarget': $($_.Exception.Message)"
        }
    }
}
