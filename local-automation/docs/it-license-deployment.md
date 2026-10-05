# Unattended Pro activation for IT

Display Dimmer 2.2.12 and later can activate a perpetual direct-purchase Lemon
Squeezy license from the installed `DisplayDimmer.Cli.exe`, including while the
app is still Free. It does not open
Display Dimmer, contact monitors, or require Pro or Local automation to be enabled.
Microsoft Store purchases still use the app's Store restore flow; this command
does not activate or purchase a Store add-on.

This is a one-shot process: run it once per intended app user during deployment
or first logon. It exits after the activation result/cache write and leaves no
resident CLI process, enabled API server or background licensing poll. No hotkey
or on/off switch is needed for this command. An already-running app still needs
restart to reload the cache; the command does not launch or restart the GUI.

## Scope and prerequisites

- Install/update the app and CLI to the same version, at least 2.2.12.
- Run as the Windows user who will use Display Dimmer. The encrypted entitlement
  is saved in that user's profile with current-user DPAPI; it is not machine-wide.
  SYSTEM, LocalService, NetworkService, anonymous identity, and unavailable or
  malformed user identity are refused.
  Running an IT tool as SYSTEM does not unlock the signed-in user's profile.
  Custom service accounts are not automatically identified: do not use them for
  activation, because their cache still belongs only to that account.
- The app need not be running. If it is already running, exit and restart it after
  activation so it reloads the entitlement. The command does not restart it.
- Supply a valid perpetual Lemon Squeezy key for Display Dimmer Pro. The command
  retains the exact approved store/current-or-legacy-product checks; it does not
  grant Pro for an arbitrary Lemon Squeezy product.
- The first successful activation needs HTTPS access to Lemon Squeezy's License
  API. A valid local cache for the same key returns success without another API
  request. Existing offline entitlement behavior remains unchanged.

One device can contain several Windows user profiles. Activating each profile
can consume a separate provider activation; plan the activation allowance around
the profiles that will actually use Pro. Choose an activation allowance that covers the intended user profiles,
device replacements, reimages, and deployment testing.

## Command forms

Preferred for deployment:

```text
DisplayDimmer.Cli.exe --activate-license --license-key-stdin --silent
```

Send the key as one line through redirected standard input, then close input.
Interactive stdin is refused. Input is bounded to 512 characters and must arrive
within 10 seconds. Use `--json` instead of `--silent` when a structured result is
needed. Do not combine the two output modes or add display/API command options.

The convenience forms `--activate-license <key>` and
`--activate-license=<key>` are also accepted. A key passed in arguments may be
visible in process listings, command history, transcripts, and deployment logs;
use redirected stdin from the deployment system's secret store instead.

This is a standalone CLI operation, not a named-pipe API request. It does not
change wire `apiVersion` or the Local automation capability revision. Normal
display-control commands still require the app running, Pro, and Local automation.

## PowerShell deployment helper

The function below receives a `SecureString` supplied by your deployment secret
store and invokes the CLI under the current Windows user. It never places the key
in process arguments, a key file, or output. The key necessarily exists briefly
in process memory while being written to the child process. Do not print it,
include it in a transcript, or embed it in a checked-in script.

```powershell
function Invoke-DisplayDimmerLicenseActivation {
    param(
        [Parameter(Mandatory = $true)]
        [string] $CliPath,
        [Parameter(Mandatory = $true)]
        [System.Security.SecureString] $LicenseKey
    )

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $CliPath
    $startInfo.Arguments = '--activate-license --license-key-stdin --silent'
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true

    $activationProcess = New-Object System.Diagnostics.Process
    $activationProcess.StartInfo = $startInfo
    $keyPointer = [IntPtr]::Zero
    try {
        if (-not $activationProcess.Start()) {
            throw 'Could not start the Display Dimmer CLI.'
        }
        # Drain both output streams so the child cannot block on a full pipe.
        $stdoutTask = $activationProcess.StandardOutput.ReadToEndAsync()
        $stderrTask = $activationProcess.StandardError.ReadToEndAsync()
        try {
            $keyPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($LicenseKey)
            $activationProcess.StandardInput.WriteLine(
                [Runtime.InteropServices.Marshal]::PtrToStringBSTR($keyPointer))
        }
        finally {
            if ($keyPointer -ne [IntPtr]::Zero) {
                [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($keyPointer)
                $keyPointer = [IntPtr]::Zero
            }
            $activationProcess.StandardInput.Close()
        }
        $activationProcess.WaitForExit()
        $null = $stdoutTask.GetAwaiter().GetResult()
        $null = $stderrTask.GetAwaiter().GetResult()
        return $activationProcess.ExitCode
    }
    finally {
        $activationProcess.Dispose()
    }
}

# Supply $deploymentLicenseKey from your IT secret store as a SecureString.
# This script runs in the intended user's context, not SYSTEM.
$cliPath = (Get-Command DisplayDimmer.Cli.exe -ErrorAction Stop).Source
$activationExit = Invoke-DisplayDimmerLicenseActivation `
    -CliPath $cliPath -LicenseKey $deploymentLicenseKey

switch ($activationExit) {
    0 { 'Pro is activated or already activated. Restart Display Dimmer if it is running.' }
    1 { throw 'Activation input or arguments were invalid.' }
    4 { throw 'Run activation in the intended supported Windows user account.' }
    5 { throw 'Activation was refused or could not be persisted. Investigate without replacing the cache.' }
    7 { throw 'Activation is busy or its network result is uncertain. Reconcile before retrying.' }
    default { throw "Unexpected Display Dimmer activation exit code: $activationExit" }
}
```

The helper performs exactly one activation attempt; it does not contain a retry
loop. Resolve the installed CLI in the intended user's environment. A device
deployment that has no user context must schedule the activation step for that
user's session or logon rather than activating a service account.

## Exit codes and safe repeat deployment

| Code | Activation meaning |
| ---: | --- |
| `0` | Activated and saved, or a valid local entitlement already has the same key. |
| `1` | Invalid arguments or key input, including stdin redirect requirements/length bounds. |
| `4` | Unsupported or unrecognized Windows account context. |
| `5` | Permanent refusal, invalid provider response, existing-cache conflict, or persistence failure. |
| `7` | Busy, stdin timeout/unavailable, cancellation, or transient network failure; the provider result may be uncertain. |

Activation output contains fixed result messages only; it does not include the
key, customer details, raw provider response, or activation instance. `--silent`
suppresses successful result output; failures still write a fixed message to
stderr. Use the process exit code for deployment decisions. The activation-specific
JSON is a CLI result, not the Local automation wire response.

The activation `--json` result has this shape (example: a new activation):

```json
{"provider":"lemonsqueezy","scope":"currentUser","outcome":"activated","success":true,"exitCode":0,"restartRequired":true}
```

`restartRequired` is true for a successful new or same-key result: restart only if
the GUI was already running. The result has no wire API version, license key,
customer fields or provider response body. `outcome` is a fixed machine-readable
value, not remote error text. Success outcomes are `activated` and
`alreadyActivated`. Failure outcomes are `invalidArguments`, `invalidInput`,
`stdinRequired`, `wrongAccount`, `existingLicensePresent`, `invalidLicense`,
`wrongProduct`, `storageError`, `protocolError`, `operationFailed`, `activationBusy`,
`networkUnavailable`, `cancelled`, `inputTimeout`, and `inputUnavailable`.

The CLI schedules overall command cancellation after 30 seconds, stdin waits at
most 10 seconds, and cache-lock acquisition waits at most 5 seconds. The existing
activation HTTP timeout is 12 seconds; a best-effort rollback uses its separate
existing 12-second timeout. These bounds do not guarantee that a provider-side
activation was cancelled or never accepted. They are not a fleet retry policy.

A cross-process lock serializes cache read, activation, and save with GUI
activation for that user. Lock contention has a bounded wait. A valid same-key
cache makes repeated deployment a successful no-op. A different key or an
unreadable existing cache is refused, so deployment cannot silently overwrite
an existing entitlement or repeatedly consume seats by discarding a damaged
cache. Do not delete the cache as an automated recovery step.

The command does not automatically retry a License API POST. A timeout can occur
after Lemon Squeezy has accepted an activation but before the app receives or
persists the response. Check the local outcome and provider activation inventory
before an operator authorizes another attempt; exit `7` is not proof that no seat
was consumed. If storage failed after a provider activation, review the outcome
and provider inventory rather than treating it as a clean unsuccessful request.

## Fleet rollout

Lemon Squeezy documents a [60-request-per-minute License API limit](https://docs.lemonsqueezy.com/api/license-api).
Use a central deployment coordinator to start at most approximately **15 new
activations per minute** (at least four seconds between starts), leaving headroom
for other License API traffic. This is a deployment policy, not a global rate
limiter built into each client. Random per-device delays alone cannot enforce a
fleet-wide ceiling, and a four-second loop on every PC still creates a burst.

Pilot a few intended-user profiles first. Confirm successful exit, launch/restart
Pro, inspect provider activation usage, then expand in centrally scheduled batches.
Keep input, account, permanent, and ambiguous transient failures separate in the
deployment report. Do not launch automatic repeated POST loops after rate limits,
timeouts, or uncertain results. Monitor the shared key's actual usage against its
activation allowance before the next batch.

Provider reference: [Activate a license key](https://docs.lemonsqueezy.com/api/license-api/activate-license-key).
No real key or activation is needed to read this guide.

## Managed app updates

Activation does not enable a resident CLI or an app updater. Display Dimmer's
optional update notice opens the Microsoft Store; it does not enforce mandatory
package updates. IT can control Store automatic updates using supported Windows
policy, which affects other Store apps on the device too. See
[managed Store updates](managed-store-updates.md) before planning a controlled
rollout. This is separate from centrally pacing License API activations.
