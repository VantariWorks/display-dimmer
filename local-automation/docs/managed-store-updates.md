# Managed Microsoft Store updates

Applies to Display Dimmer 2.2.12. This guide explains the app's update behavior
and Microsoft Store controls for managed Windows deployments.

## What Display Dimmer does

The app does not download or install its own updates. It checks the small
`https://displaydimmer.com/latest-version.txt` file with a bounded request and a
saved 24-hour throttle. When Main is visible and ready, an available-version
notice offers **Not now** or **Update**; Update opens the Microsoft Store product
page. It does not stop the app or revoke Pro because an update is available.

The app does not call Store package-update discovery, download/install or
mandatory-update enforcement APIs. Selecting **Make this update mandatory** in
Partner Center does not add that behavior. Microsoft documents mandatory status
as metadata for app-enforced behavior, rather than OS enforcement.

## Managed controls

On supported managed Windows Pro, Enterprise, Education and IoT Enterprise
devices, the IT administrator can configure either:

- MDM: `./Device/Vendor/MSFT/Policy/Config/ApplicationManagement/AllowAppStoreAutoUpdate`
  with integer value `0` (not allowed).
- Group Policy: enable **Computer Configuration > Administrative Templates >
  Windows Components > Store > Turn off Automatic Download and Install of updates**.

These control automatic updates for Store apps on the device; they do not pin
only Display Dimmer to a selected version. Check OS/management support and the
organization's other app-update requirements before applying them. An MDM or
deployment tool's explicit app install/update action is a separate management
decision; this guide does not promise to block it.

After disabling automatic Store updates, IT remains responsible for choosing and
delivering updates. The optional Display Dimmer version notice can still appear;
there is no separate managed switch for that notice or an app-specific updater
in this release. A consumer Store pause is not a permanent fleet update policy.

No separately signed offline installer, MSI/MSIX license injection or per-app
version-pin channel is shipped by this change. A generated unsigned `.msixupload`
is for Store submission, not an installer to send to an organization.

## Activation is separate

The one-shot IT activation command works before Pro or Local automation is
enabled and does not enable an updater or resident CLI process. It saves the
license only for the invoking Windows user. If the GUI is already open, restart
it after successful activation. Plan seats per activated user profile and pace
new activations centrally; consult [IT license deployment](it-license-deployment.md)
alongside this page.

## Sources

- [Microsoft: mandatory package updates](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/package-updates-from-store#mandatory-package-updates)
- [Microsoft: AllowAppStoreAutoUpdate scope and values](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-applicationmanagement#allowappstoreautoupdate)
- [Microsoft: packaged-app Group Policy](https://learn.microsoft.com/en-us/windows/msix/group-policy-msix#turn-off-automatic-download-and-install-of-updates)
