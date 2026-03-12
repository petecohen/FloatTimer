# FloatTimer

A tiny floating countdown timer for macOS that stays above everything — including full-screen presentations.

Built for workshop facilitators who need to keep time without breaking flow.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue) ![License: MIT](https://img.shields.io/badge/License-MIT-green) ![Latest Release](https://img.shields.io/github/v/release/petecohen/FloatTimer)

## What it does

FloatTimer puts a small, draggable countdown pill on your screen that floats above every app — Keynote, PowerPoint, Zoom screen shares, even full-screen presentations. Click the menu bar icon to start a timer, and it stays visible while you present.

## Install

**[Download the latest release](https://github.com/petecohen/FloatTimer/releases/latest)** — grab the `.dmg` file, open it, and drag FloatTimer to your Applications folder.

> **First launch:** macOS will block the app because it isn't notarised (that costs $99/year). Go to **System Settings → Privacy & Security**, scroll down, and click **Open Anyway**. You only need to do this once. See the [website](https://floattimer.netlify.app/#install) for detailed instructions.

## Usage

- **Menu bar** — click the ⏱ icon to pick a preset (1–30 min), enter a custom duration, pause, stop, or open preferences
- **Right-click the pill** — same controls, accessible directly from the timer
- **Drag** — move the pill anywhere on screen; it remembers its position

### Keyboard shortcuts

| Action | Default shortcut |
|---|---|
| Start / Pause / Resume | `⌃⇧S` |
| Reset | `⌃⇧R` |
| Show / Hide | `⌃⇧T` |

All shortcuts are customisable in Preferences.

## Preferences

Right-click the pill → **Preferences**, or use the menu bar → **Preferences** (`⌘,`):

- **Background colour** and **text colour**
- **Corner radius** — from square to fully rounded pill
- **Keyboard shortcuts** — click a field and press your preferred key combination

## Build from source

Requires macOS 13+ and Xcode Command Line Tools.

```bash
git clone https://github.com/petecohen/FloatTimer.git
cd FloatTimer
bash Scripts/bundle.sh
open .build/FloatTimer.app
```

### Create a release DMG

```bash
bash Scripts/release.sh 1.3.0
```

## How it works

- Native Swift app — no Electron, no browser, no dependencies
- `NSPanel` with `.screenSaver` level + `.fullScreenAuxiliary` collection behaviour to float above full-screen apps
- `DispatchSourceTimer` with wall-clock elapsed time for accurate countdown
- Global keyboard shortcuts via `NSEvent.addGlobalMonitorForEvents` (requires Accessibility permission)
- Menu bar only (`LSUIElement`) — no dock icon

## Links

- **Website:** [floattimer.netlify.app](https://floattimer.netlify.app)
- **Author:** [petecohen.me](https://www.petecohen.me)
- **Support:** [Buy me a coffee](https://buymeacoffee.com/petecohen)

## License

MIT
