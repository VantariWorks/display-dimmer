# Display Dimmer

Display Dimmer is a Windows app for controlling external monitor brightness and contrast from one place.

It can use DDC/CI when supported to adjust a monitor's hardware brightness directly. When hardware control is not available or does not behave reliably, Display Dimmer can fall back to software dimming so you can still control brightness from Windows.

[Learn more at displaydimmer.com](https://displaydimmer.com/)

## What It Does

- Adjust brightness and contrast for external monitors
- Control individual displays or all displays together
- Keep relative brightness levels when adjusting all displays
- Create scheduled brightness rules
- Create app-based and fullscreen app rules
- Use global hotkeys for brightness, contrast, and display actions
- Use supported physical brightness keys
- Start with Windows and reapply brightness on launch
- Run quietly from the system tray
- Use light, dark, system, and additional Pro themes

## Monitor Control

Display Dimmer supports DDC/CI monitor control where available.

DDC/CI support depends on the monitor, cable, dock, adapter, GPU, and display settings. Some monitors require DDC/CI to be enabled in the monitor's built-in menu. Some displays do not support hardware brightness control at all.

If DDC/CI is unavailable, disabled, unsupported, or unreliable on a specific display, Display Dimmer can use software dimming instead. You can also turn DDC/CI on or off per display.

## Automation

Display Dimmer can adjust brightness automatically based on time of day or the app you are using.

Schedules are useful for day/night brightness changes. App rules are useful for games, video players, design tools, presentations, and other apps that need a different brightness level.

When an automation rule ends, Display Dimmer is designed to restore your previous brightness so your setup stays predictable.

## Hotkeys

Global hotkeys can be used to adjust brightness and contrast without opening the app.

Display Dimmer also supports physical brightness keys on supported keyboards and devices.

## Display Dimmer Pro

Display Dimmer includes core brightness control, basic automation, and basic hotkey support for free.

Display Dimmer Pro is an optional one-time upgrade. Pro unlocks more schedules, more app rules, more hotkeys, per-display automation and hotkey targeting, linked display groups, advanced controls, and all Pro themes.

No subscription.

## Install

Display Dimmer is available from the Microsoft Store:

[Download Display Dimmer](https://apps.microsoft.com/detail/9NBWHFCLN6CM?cid=github)

[View release history](CHANGELOG.md)

## Support

For help, bug reports, or compatibility issues:

- Support page: https://displaydimmer.com/contact
- Privacy policy: [PRIVACY.md](PRIVACY.md)
- Email: support@displaydimmer.com

When reporting monitor-control issues, please include:

- Display Dimmer version
- Windows version
- Monitor model
- Connection type, such as HDMI, DisplayPort, USB-C, dock, or adapter
- GPU / graphics adapter
- Whether HDR is enabled
- Whether DDC/CI is enabled in the monitor's built-in menu
- What happened before the issue started, such as sleep/resume, reconnecting a
  display, changing HDR, switching ports, or using a dock

## Notes

- Display Dimmer is currently for Windows.
- The app interface is currently in English.
- Hardware brightness control is limited by what your monitor and display path support.
- Software dimming is used when hardware brightness control is unavailable or unreliable.

## Repository purpose

This repository is used for Display Dimmer support information, release notes, and public documentation. The app source code is not currently published here.
