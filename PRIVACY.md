# Privacy Policy

Last updated: October 5, 2026

This policy explains how Display Dimmer and the Display Dimmer website handle
data. Display Dimmer is built as a local-first Windows app for controlling
display brightness, contrast, and color temperature.

## Summary

- Display Dimmer does not require an app account.
- Display Dimmer does not include in-app advertising SDKs or third-party ad
  trackers.
- Brightness settings, display preferences, saved presets, schedules, app rules,
  hotkeys, and themes are stored locally on your device.
- Display Dimmer sends a small amount of anonymous usage and reliability
  telemetry to help improve the app.
- Detailed diagnostics reports are sent only after you choose to send a
  diagnostics report.

## Website

The Display Dimmer website is operated by Vantari Works and hosted on
Cloudflare Pages. It uses Google Analytics for basic traffic information,
including pages, referrals, approximate region, and browser/device type.
Analytics may use first-party cookies to distinguish visits or sessions; the
site does not use personalized advertising.

The activation and nonprofit application pages exclude Google Analytics.
License keys and nonprofit application contents are not sent to analytics.
The Mac beta and nonprofit forms collect the contact and request details you
submit using Cloudflare services, with Cloudflare Turnstile for abuse checks.
For the current fields, website events, and related choices, see the
[website privacy policy](https://displaydimmer.com/privacy).

If you contact Display Dimmer support by email, your message and email address
are used to respond and provide support.

## Local App Data

Display Dimmer stores its settings locally on your device. This can include:

- brightness, contrast, and temperature levels
- saved presets, including their names, included levels, and display targets
- display labels
- enabled or disabled display state
- DDC/CI hardware-control preference
- schedules
- app rules
- hotkeys
- linked display groups
- themes and window settings
- Pro state
- rating prompt state
- diagnostics prompt state

Display Dimmer also stores local display reliability data, such as DDC/CI
known-good and failure history. This helps avoid repeated bad hardware-control
writes and helps explain when Display Dimmer falls back to software dimming.

To provide per-display control, Display Dimmer reads technical information
about your system and displays, such as connected monitors, display
capabilities like DDC/CI support, and basic Windows and graphics information.
This information is used by the app to function and is not used to build a
browsing or activity profile.

## Anonymous Usage And Reliability Telemetry

Display Dimmer sends a small amount of anonymous usage and reliability
telemetry to help Vantari Works understand how the app is used and improve
stability. This telemetry is event-style data and may include:

- when the app starts, such as whether it is a new install or returning session,
  plus the app version
- which settings areas are used, such as Schedules, App Rules, Hotkeys, or Pro
- when certain features are enabled, such as schedules, app rules, Gamma Guard,
  Start with Windows, or DDC/CI brightness control
- coarse DDC/CI reliability information, such as failure reason categories and
  connection or HDR/topology state buckets
- coarse Pro upgrade or restore flow results, such as whether a Microsoft Store
  request succeeded, failed, or was canceled
- whether crash or hang detectors were triggered

Telemetry does not include your name, email address, Microsoft account
identifier, payment information, personal documents, screenshots, browser
history, window titles, app-rule executable paths, full file paths, monitor
serial numbers, raw display identities, full hardware IDs, or a persistent
user/device identifier.

Telemetry is used in aggregate to understand product usage and identify
reliability issues.

## Optional Diagnostics Reports

Display Dimmer can create diagnostics reports to help debug crashes, hangs,
DDC/CI failures, gamma fallback issues, startup problems, shutdown problems,
and display reconnect issues. Diagnostics reports are only sent after you
choose to send a diagnostics report.

A diagnostics report may include technical information such as:

- Windows version and build information
- basic hardware details, such as CPU or GPU model
- monitor information, such as model names and connection details
- current Display Dimmer configuration, such as enabled features, schedules,
  app rules, hotkeys, and linked display groups, with sensitive paths scrubbed
  where possible
- recent Display Dimmer logs, including error messages and timing information
  related to brightness control

Diagnostics reports are scrubbed before upload and are designed to exclude
personal files, screenshots, browser history, passwords, raw settings files,
usernames, machine names, and full local file paths. They may still contain
technical details about your device and Display Dimmer setup that are useful
for debugging.

Diagnostics data is used only to investigate bugs, understand compatibility
issues, and improve Display Dimmer. It is not sold to third parties or used for
advertising.

## Network Services

Core brightness control does not require an account, cloud sync, or a network
connection.

Display Dimmer may contact Display Dimmer services to send anonymous telemetry,
send an opt-in diagnostics report, check the latest available version, or load
What's New text. Help and guide links open the Display Dimmer website only when
you choose to open them.

These network calls are not required for local brightness control, and failures
are handled without blocking the app's core display-control behavior.

## Microsoft Store Data

Display Dimmer is distributed through the Microsoft Store. Depending on your
Microsoft account and Windows privacy settings, Microsoft may provide Vantari
Works with aggregated statistics such as install counts, device and OS versions,
regions, and app usage summaries. This data does not include the content of
support emails, diagnostics reports, or payment card details.

Microsoft Store purchases, payment information, Store ratings, and Store reviews
are handled by Microsoft. Display Dimmer may use Microsoft Store APIs to check Pro entitlement,
start purchase or restore flows, request regional Pro price text, or open the
Store rating experience. Vantari Works does not receive your full payment card
details.

## Direct Pro Purchases And License Activation

Direct-purchase checkout is provided by Lemon Squeezy. An app-opened checkout
link can include a fixed purchase-source label, app version, a coarse two-letter
Windows region code, and a monitor-count bucket. These fields describe the
purchase context; they do not include monitor identities or app-rule paths.
See [Lemon Squeezy's privacy policy](https://www.lemonsqueezy.com/privacy) for its
handling of checkout and purchase information.

When you activate a direct-purchase key, Display Dimmer sends the key and a
generic app instance label to Lemon Squeezy's License API over HTTPS. It does
not send the Windows machine name as that label. If a new activation cannot be
accepted or saved locally, the app may send the key and returned activation
instance ID once to release that activation.

The local direct-license cache contains the key, activation instance ID,
store/product/variant metadata, license status, and a validation timestamp.
It is encrypted with Windows current-user DPAPI in the invoking user's profile.
The app does not put the key in telemetry, diagnostics reports, or logs.
An existing valid local cache permits offline Pro use without background license
polling. The standalone IT activation command uses the same current-user cache;
it does not enable a resident CLI or Local automation server.

Website-assisted activation links can contain the key in an HTTPS URL and a
`displaydimmer:` protocol URI, where browser history and Windows protocol
handling may expose it. Treat those links as secrets. For IT deployment, the
[redirected-stdin command](local-automation/docs/it-license-deployment.md) keeps
the key out of process arguments; passing a key directly in arguments can expose
it through command history, process listings, or deployment logs.

## Sharing And Retention

Vantari Works does not sell personal information, support messages, diagnostics
reports, or telemetry data.

Support messages and diagnostics reports are kept only as long as reasonably
needed to provide support, investigate issues, improve Display Dimmer, or meet
legal and operational requirements.

Local Display Dimmer settings and diagnostics logs remain on your device until
the app, Windows, or you remove them.

## Support

Questions about this privacy policy, or requests related to support messages or
diagnostics reports, can be sent to:

- Email: support@displaydimmer.com
- Support page: https://displaydimmer.com/support
- Privacy policy: https://displaydimmer.com/privacy
