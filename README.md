# Elapsed

A macOS menu bar app that tracks how long you've been working continuously.

Elapsed runs quietly in your menu bar, automatically detecting when you're active at your computer. It monitors your work sessions and reminds you to take breaks.

## Features

- **Automatic session tracking** — detects keyboard/mouse activity to start and end sessions
- **Menu bar timer** — always visible elapsed time in `HH:MM` format
- **Break reminders** — configurable notifications when you've been working too long
- **Session statistics** — view your work patterns by day, week, or month
- **Session history** — browse past sessions grouped by date

## Install

1. Download the latest `.zip` from [Releases](https://github.com/ta21cos/elapsed/releases)
2. Unzip and move `Elapsed.app` to `/Applications`
3. On first launch, right-click the app and select **Open** (Gatekeeper bypass, one-time only)
4. Grant **Accessibility** permission when prompted (required for activity detection)

## Requirements

- macOS 14.0 (Sonoma) or later

## Build from source

```bash
git clone https://github.com/ta21cos/elapsed.git
cd elapsed
xcodebuild -project Elapsed.xcodeproj -scheme Elapsed -configuration Release build
```

## License

MIT
