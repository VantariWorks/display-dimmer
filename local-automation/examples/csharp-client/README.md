# C# Client Example

This sample is for developers building a local Display Dimmer integration. It is not a separate SDK; normal command-line use can call `DisplayDimmer.Cli.exe` directly.

The sample shows how a C# app can call `DisplayDimmer.Cli.exe`, read JSON output, choose a display, send a brightness command, and then read state back.

## What It Does

1. Runs `DisplayDimmer.Cli.exe --list-displays --json`.
2. Parses the JSON response.
3. Selects the first display where `controlEnabled` is `true`.
4. Sends `--set-brightness <value> --target <targetId> --source csharp-client-example --json`.
5. Runs `--get-state --target <targetId> --pretty`.

For a real integration, show the display list during setup and store the selected `targetId`. Prefer `dd_...` values for saved scripts. If the returned `targetId` is `display_1`, treat it as session-only and rerun `--list-displays` after display changes.

## Requirements

- Display Dimmer must already be running.
- Local automation requires Display Dimmer Pro.
- Local automation must be turned on in Settings > General > Advanced > Local automation > Manage...
- The installed `DisplayDimmer.Cli.exe` command must be available in PowerShell.
- Run the C# app as the same Windows user as Display Dimmer.

## Run

Run the sample with the installed command-line tool:

```powershell
dotnet run --project .\examples\csharp-client\DisplayDimmer.CliClientExample.csproj -- DisplayDimmer.Cli.exe 70
```

If another script needs the exact command-line tool path, resolve it with:

```powershell
$cliPath = (Get-Command DisplayDimmer.Cli.exe -ErrorAction Stop).Source
dotnet run --project .\examples\csharp-client\DisplayDimmer.CliClientExample.csproj -- $cliPath 70
```

Arguments:

- first argument: Display Dimmer command-line tool path or command (`DisplayDimmer.Cli.exe`)
- second argument: brightness from `0` to `100`

## Integration Guidance

Call `DisplayDimmer.Cli.exe` from external tools and let the running Display Dimmer app handle monitor control, DDC/CI, software dimming, display identity, schedules, app rules, and automation handoff.

The CLI is the supported boundary. Client apps should not talk to monitors directly or duplicate Display Dimmer's display identity logic.
