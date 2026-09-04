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

![Wikey home](docs/images/home.png)

Wikey connects app launches, websites, reusable rich-text templates, and window layouts into workflows that run in order. Assign a one- or two-step global shortcut and start the workflow from anywhere on your Mac.

All workflows and templates stay on your Mac and are not sent to an external server.

## Quick start

1. Download `Wikey-version.dmg` from the [latest release](https://github.com/movvgli/Wikey/releases/latest).
2. Move Wikey to **Applications** and launch it.
3. Use the first-run introduction to review the core features and enable only the permissions you need.
4. Create a workflow, add actions, and assign a shortcut.

Release builds are signed with Developer ID and notarized by Apple. Wikey requires macOS 15 or later.

## Features

| Feature | What it does |
| --- | --- |
| Workflows | Connect multiple actions and run them from top to bottom. |
| Global shortcuts | Use a single chord or a sequence of up to two chords. |
| Apps and websites | Launch apps and open URLs in the default browser. |
| Rich templates | Copy or automatically paste formatted text, links, lists, and inline images. |
| Window layouts | Arrange apps across displays in full, half, third, two-thirds, and quadrant zones. |
| Quick access | Run workflows from the menu bar and prepare Wikey at login. |
| Updates | Check, download, and install new versions inside the app. |

If an action fails, Wikey records the failure and continues with the remaining actions when possible.

## Permissions and privacy

Wikey asks only for the macOS permissions required by the features you use.

| Permission | Used for |
| --- | --- |
| Accessibility | Moving and resizing other app windows; automatic paste |
| Input Monitoring | Reading the second chord in a two-step shortcut |

Single-chord shortcuts, app launching, websites, and clipboard copy work without these permissions. See the [privacy guide](docs/PRIVACY.md) for details.

## Updates

Wikey checks for a new version once per day while it is running. You can also use **Wikey → Check for Updates…** or **Settings → Updates**. Automatic downloads remain under your control.

## Development

Requirements:

- macOS 15 or later
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
