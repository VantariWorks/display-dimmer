[CmdletBinding()]
param(
    # Minutes without keyboard or mouse input before dimming (default: 5).
    [ValidateRange(1, 1440)]
    [int]$IdleMinutes = 5,

    # Optional short interval for a supervised test.
    [ValidateRange(0, 3600)]
    [int]$IdleSeconds = 0,

    # Brightness percentage used while idle (default: 20).
    [Alias("SetBrightness")]
    [ValidateRange(0, 100)]
    [int]$DimBrightness = 20,

    # How often to check for input. One second is usually sufficient.
    [ValidateRange(1, 60)]
    [int]$PollSeconds = 1,

    # Print intended changes without sending brightness commands.
    [switch]$DryRun,

    # Optional explicit path to DisplayDimmer.Cli.exe.
    [string]$CliPath
)

$ErrorActionPreference = "Stop"

# GetLastInputInfo reports input in this Windows user session. The unsigned
# subtraction handles the normal 32-bit tick counter wrap.
if (-not ("DisplayDimmerIdleExample.LastInput" -as [type])) {
    Add-Type -Namespace DisplayDimmerIdleExample -Name LastInput -MemberDefinition @'
[System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]
private struct LASTINPUTINFO
{
    public uint cbSize;
    public uint dwTime;
}

[System.Runtime.InteropServices.DllImport("user32.dll")]
private static extern bool GetLastInputInfo(ref LASTINPUTINFO info);

public static uint IdleMilliseconds()
{
    var info = new LASTINPUTINFO();
    info.cbSize = (uint)System.Runtime.InteropServices.Marshal.SizeOf(typeof(LASTINPUTINFO));
    if (!GetLastInputInfo(ref info))
        throw new System.ComponentModel.Win32Exception();

    return unchecked((uint)System.Environment.TickCount - info.dwTime);
}
'@
}

if ([string]::IsNullOrWhiteSpace($CliPath)) {
    $command = Get-Command "DisplayDimmer.Cli.exe" -CommandType Application -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        throw "DisplayDimmer.Cli.exe was not found. Start Display Dimmer, enable Local automation, or pass -CliPath."
    }
    $CliPath = $command.Source
}
elseif (Test-Path -LiteralPath $CliPath) {
    $CliPath = (Resolve-Path -LiteralPath $CliPath).ProviderPath
}
elseif ($null -eq (Get-Command $CliPath -CommandType Application -ErrorAction SilentlyContinue)) {
    throw "DisplayDimmer.Cli.exe was not found at: $CliPath"
}

function Invoke-DisplayDimmerJson {
    param([string[]]$Arguments)

    $output = & $script:CliPath @Arguments
    $exitCode = $LASTEXITCODE
    $json = ($output -join "").Trim()
    if ([string]::IsNullOrWhiteSpace($json)) {
        throw "Display Dimmer returned no JSON (exit $exitCode)."
    }

    try {
        $response = $json | ConvertFrom-Json
    }
    catch {
        throw "Display Dimmer returned invalid JSON (exit $exitCode)."
    }

    if ($exitCode -ne 0 -or $null -eq $response -or $response.success -ne $true) {
        throw "Display Dimmer command failed (exit $exitCode): $($response.errorCode) $($response.message)"
    }

    return $response
}

function Get-DisplayKey {
    param($Display)

    $target = [string]$Display.targetId
    if ($target.StartsWith("dd_", [System.StringComparison]::OrdinalIgnoreCase)) {
        return "stable:$target"
    }

    # A display_N target can be reused after hotplug. Require the same
    # reported identity before restoring through its current target ID.
    if (-not [string]::IsNullOrWhiteSpace([string]$Display.identity)) {
        return "identity:$($Display.identity)"
    }

    return $null
}

function Get-DisplayState {
    $response = Invoke-DisplayDimmerJson -Arguments @("--get-state", "--target", "all", "--json")
    $script:resumeSupported = @($response.capabilities) -contains "resume-automation"
    return @($response.displays)
}

function Get-DisplayForKey {
    param([string]$Key)

    $matches = @(Get-DisplayState | Where-Object {
        $null -ne $_ -and (Get-DisplayKey -Display $_) -eq $Key
    })
    if ($matches.Count -ne 1) {
        return $null
    }
    return $matches[0]
}

function Request-AutomationResume {
    param($Saved, $Display)

    try {
        Invoke-DisplayDimmerJson -Arguments @(
            "--resume-automation", "--target", [string]$Display.targetId,
            "--expected-brightness", [string]$DimBrightness, "--json"
        ) | Out-Null
    }
    catch {
        Write-Warning "Could not resume automation for $($Display.name): $_"
        # A failed resume must not restore the captured manual value over a
        # still-interrupted rule. Keep this entry for the next activity check.
        return "retry"
    }

    # Resume requests a rule reassert, which may finish after the CLI reply.
    # If no rule still owns the display, restore its captured level instead.
    for ($attempt = 0; $attempt -lt 6; $attempt++) {
        Start-Sleep -Milliseconds 300
        try {
            $latest = Get-DisplayForKey -Key $Saved.Key
        }
        catch {
            Write-Warning "Could not confirm automation state for $($Display.name): $_"
            return "retry"
        }
        if ($null -eq $latest -or $latest.isConnected -ne $true -or
            $latest.controlEnabled -ne $true -or $null -eq $latest.brightness) {
            return "retry"
        }
        if ([int]$latest.brightness -ne $DimBrightness -or
            ($latest.scheduleActive -eq $true -and $latest.scheduleInterrupted -ne $true) -or
            ($latest.perAppActive -eq $true -and $latest.perAppInterrupted -ne $true)) {
            return "resumed"
        }
    }

    if ($latest.scheduleActive -eq $true -or $latest.perAppActive -eq $true) {
        return "retry"
    }
    return "fallback"
}

function Restore-DimmedDisplays {
    try {
        $current = Get-DisplayState
    }
    catch {
        Write-Warning "Could not read Display Dimmer state for restore: $_"
        return
    }

    $byKey = @{}
    foreach ($display in $current) {
        $key = Get-DisplayKey -Display $display
        if ($null -ne $key) {
            if ($byKey.ContainsKey($key)) {
                $byKey[$key] = $null
            }
            else {
                $byKey[$key] = $display
            }
        }
    }

    foreach ($saved in @($script:pendingRestore.Values)) {
        if (-not $byKey.ContainsKey($saved.Key)) {
            continue
        }

        $display = $byKey[$saved.Key]
        if ($null -eq $display) {
            continue
        }
        if ($display.isConnected -ne $true -or $display.controlEnabled -ne $true -or
            $null -eq $display.brightness) {
            continue
        }

        if ([int]$display.brightness -ne $DimBrightness) {
            # A user or another controller changed the level while idle.
            $script:pendingRestore.Remove($saved.Key)
            Write-Host "Leaving $($display.name) at its newer brightness."
            continue
        }

        if ($saved.ResumeAutomation) {
            $outcome = Request-AutomationResume -Saved $saved -Display $display
            if ($outcome -eq "resumed") {
                $script:pendingRestore.Remove($saved.Key)
                Write-Host "Released idle override for $($display.name); automation can take control."
                continue
            }
            if ($outcome -eq "retry") {
                continue
            }

            # A rule may have ended while idle, or this app/CLI may not support
            # resume yet. Recheck identity and level before numeric fallback.
            try {
                $display = Get-DisplayForKey -Key $saved.Key
            }
            catch {
                Write-Warning "Could not recheck $($saved.Key) before restore: $_"
                continue
            }
            if ($null -eq $display -or $display.isConnected -ne $true -or
                $display.controlEnabled -ne $true -or $null -eq $display.brightness) {
                continue
            }
            if ([int]$display.brightness -ne $DimBrightness) {
                $script:pendingRestore.Remove($saved.Key)
                continue
            }
            if ($display.scheduleActive -eq $true -or $display.perAppActive -eq $true) {
                # Never replace an active owner's value with the old numeric
                # baseline, even if its reassert has not completed yet.
                continue
            }
        }

        if (($display.scheduleActive -eq $true -and
                ($display.scheduleInterrupted -ne $true -or -not $saved.PriorSchedulePaused)) -or
            ($display.perAppActive -eq $true -and
                ($display.perAppInterrupted -ne $true -or -not $saved.PriorPerAppPaused))) {
            # Do not write over a rule that took control while idle. A rule
            # already paused before idle can keep its captured manual level.
            $script:pendingRestore.Remove($saved.Key)
            Write-Warning "Leaving $($display.name) at its current level because automation changed while idle."
            continue
        }

        try {
            Invoke-DisplayDimmerJson -Arguments @(
                "--set-brightness", [string]$saved.Brightness,
                "--target", [string]$display.targetId, "--source", "cli", "--json"
            ) | Out-Null
            $script:pendingRestore.Remove($saved.Key)
            Write-Host "Restored $($display.name) to $($saved.Brightness)%."
        }
        catch {
            Write-Warning "Could not restore $($display.name): $_"
        }
    }
}

$idleThreshold = if ($IdleSeconds -gt 0) {
    [long]$IdleSeconds * 1000
}
else {
    [long]$IdleMinutes * 60 * 1000
}
$pendingRestore = @{}
$idleHandled = $false
$nextDimAttempt = [DateTime]::MinValue
$nextRestoreAttempt = [DateTime]::MinValue

Write-Host "Watching this Windows session. After $($idleThreshold / 1000) second(s) idle, dim eligible displays to $DimBrightness%."
if ($DryRun) {
    Write-Host "Dry run: brightness will not change."
}
else {
    Write-Host "Activity restores each unchanged display. Press Ctrl+C to stop."
}
Write-Host "If Display Dimmer is still starting, the next idle check will retry."

try {
    while ($true) {
        $idleMilliseconds = [DisplayDimmerIdleExample.LastInput]::IdleMilliseconds()
        $now = [DateTime]::UtcNow

        if ($idleMilliseconds -lt $idleThreshold) {
            $idleHandled = $false
            if ($pendingRestore.Count -gt 0 -and $now -ge $nextRestoreAttempt) {
                Restore-DimmedDisplays
                $nextRestoreAttempt = $now.AddSeconds(5)
            }
        }
        elseif (-not $idleHandled -and $now -ge $nextDimAttempt) {
            try {
                $displays = Get-DisplayState
                $idleHandled = $true

                foreach ($display in $displays) {
                    if ([DisplayDimmerIdleExample.LastInput]::IdleMilliseconds() -lt $idleThreshold) {
                        break
                    }
                    if ($display.isConnected -ne $true -or $display.controlEnabled -ne $true -or
                        $display.supportsBrightness -ne $true -or $null -eq $display.brightness -or
                        [string]::IsNullOrWhiteSpace([string]$display.targetId)) {
                        continue
                    }

                    $key = Get-DisplayKey -Display $display
                    if ($null -eq $key -or $pendingRestore.ContainsKey($key) -or
                        [int]$display.brightness -le $DimBrightness) {
                        continue
                    }

                    $unpausedOwner = (($display.scheduleActive -eq $true -and $display.scheduleInterrupted -ne $true) -or
                        ($display.perAppActive -eq $true -and $display.perAppInterrupted -ne $true))
                    $priorInterruption = ($display.scheduleInterrupted -eq $true -or $display.perAppInterrupted -eq $true)
                    if ($unpausedOwner -and $priorInterruption) {
                        # Resume releases both schedule and app-rule pauses.
                        # Keep any pause that was already present before idle.
                        Write-Warning "Skipping $($display.name): automation has a mixed active/interrupted state."
                        continue
                    }
                    $resumeAutomation = $unpausedOwner
                    if ($resumeAutomation -and -not $script:resumeSupported) {
                        Write-Warning "Skipping $($display.name): the running Display Dimmer version cannot resume its active automation after idle."
                        continue
                    }

                    if ($DryRun) {
                        Write-Host "Would dim $($display.name) from $($display.brightness)% to $DimBrightness%."
                        continue
                    }

                    # Keep the captured level even if a CLI timeout leaves the
                    # app-side outcome uncertain. Restore checks live state.
                    $pendingRestore[$key] = [pscustomobject]@{
                        Key = $key
                        Brightness = [int]$display.brightness
                        PriorSchedulePaused = ($display.scheduleActive -eq $true -and $display.scheduleInterrupted -eq $true)
                        PriorPerAppPaused = ($display.perAppActive -eq $true -and $display.perAppInterrupted -eq $true)
                        # Preserve an interruption that already existed. A temporary
                        # idle override should release only previously active rules.
                        ResumeAutomation = $resumeAutomation
                    }
                    try {
                        Invoke-DisplayDimmerJson -Arguments @(
                            "--set-brightness", [string]$DimBrightness,
                            "--target", [string]$display.targetId, "--source", "cli", "--json"
                        ) | Out-Null
                        Write-Host "Dimmed $($display.name) from $($display.brightness)% to $DimBrightness%."
                    }
                    catch {
                        Write-Warning "Could not dim $($display.name): $_"
                    }
                }
            }
            catch {
                $nextDimAttempt = $now.AddSeconds(10)
                Write-Warning "Could not read Display Dimmer state: $_"
            }
        }

        Start-Sleep -Seconds $PollSeconds
    }
}
finally {
    if ($pendingRestore.Count -gt 0) {
        Restore-DimmedDisplays
    }
}
