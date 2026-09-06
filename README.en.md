<p align="center">
  <img src="Sources/Wikey/Resources/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png" width="128" alt="Wikey app icon">
</p>

<h1 align="center">Wikey</h1>

<p align="center">
  Finish repetitive work with one shortcut on macOS
</p>

<p align="center">
  <a href="https://github.com/movvgli/Wikey/releases/latest"><strong>Download the latest release</strong></a>
  · <a href="README.md">한국어</a>
  · <a href="docs/INSTALL.md">Installation</a>
  · <a href="docs/PRIVACY.md">Privacy</a>
</p>

Wikey connects app launches, websites, text, image and file pasting, and window layouts into ordered macOS workflows. Assign shortcuts to a workflow, an individual app, or a saved layout.

All workflows and templates stay on your Mac and are not sent to an external server.

## Quick start

1. Download `Wikey-version.dmg` from the [latest release](https://github.com/movvgli/Wikey/releases/latest).
2. Move Wikey to **Applications** and launch it.
3. Use the first-run introduction to review the core features and enable only the permissions you need.
4. Assign a shortcut in **Apps**, or create a workflow to connect several actions.
5. Try new workflows in a disposable document first to check their order and input destination.

Starting with 1.2.6, Wikey targets macOS 14 or later. Apple Silicon and Intel builds and minimum-OS validation pass; execution on actual macOS 14 and Intel hardware remains unverified. Production distribution uses DMGs verified for Developer ID signing and Apple notarization; see the [release notes](https://github.com/movvgli/Wikey/releases) for each version's distribution status.

## Features

| Feature | What it does |
| --- | --- |
| Workflows | Run actions in order and reuse another saved workflow as an action. |
| Global shortcuts | Use one or two chords, with conflict feedback across workflows, apps, and layouts. |
| Apps | Search installed apps, launch them directly, and assign or clear shortcuts in the list. |
| Websites | Open URLs in the default browser. |
| Rich templates | Save formatted text, links, lists, and inline images; choose a template while configuring a paste action. Templates can also be deleted. |
| Images and files | Select multiple images or files to paste into the destination app. |
| Key input and waits | Add Enter, Shift + Enter, and waits of 0.1–30 seconds between actions. |
| Window layouts | Arrange windows on connected displays in full, half, third, two-thirds, and quadrant zones. Assign a shortcut directly to a layout. |
| Execution controls | See the current action and queued runs, or stop execution and clear the queue. |
| Quick access | Run workflows from the menu bar and prepare Wikey at login. |
| Updates | Check, download, and install new versions inside the app. |

If an action fails, Wikey stops the remaining actions in that workflow and identifies the failing step. For example, a failed app launch will not be followed by a paste or Enter action. Actions that have already completed are not undone.

Pasting and window resizing depend on the destination app's support. Add a **Wait** action before Enter when an app needs time to prepare an attachment. A fixed wait does not detect upload completion, so check message-sending workflows on a non-sending test surface first.

## Permissions and privacy

Wikey asks only for the macOS permissions required by the features you use.

| Permission | Used for |
| --- | --- |
| Accessibility | Window movement and resizing, paste and Enter input, and preventing the second shortcut key from typing into another app |
| Input Monitoring | Reading the second chord in a two-step shortcut |

Opening an app or website with a single-chord shortcut, and copying to the clipboard, work without these permissions. Paste, key input, and window placement need Accessibility; two-step shortcuts need both permissions. See the [privacy guide](docs/PRIVACY.md) for details.

## Updates

Wikey checks for a new version once per day while it is running. You can also use **Wikey → Check for Updates…** or **Settings → Updates**. Automatic downloads remain under your control.

## Development

Requirements:

- A macOS version supported by your Xcode (the app deployment target is macOS 14)
- Xcode and a Swift 6 toolchain
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) when regenerating the Xcode project

```sh
./script/build_and_run.sh
swift test
xcodegen generate
```

See [Distribution](docs/DISTRIBUTION.md) for packaging and notarization steps.

## Contributing

Bug reports and focused improvements are welcome. Read [Contributing](CONTRIBUTING.md) and the [Code of Conduct](CODE_OF_CONDUCT.md). Please report security issues through [Security](SECURITY.md), not a public issue.

## License

[MIT License](LICENSE)
