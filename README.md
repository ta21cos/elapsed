# Elapsed

A macOS menu bar app that tracks how long you've been working continuously.

Elapsed runs quietly in your menu bar, automatically detecting when you're active at your computer. It monitors your work sessions and reminds you to take breaks.

## Features

- **Automatic session tracking** — detects keyboard/mouse activity to start and end sessions
- **Menu bar timer** — always visible elapsed time in `HH:MM` format
- **Break reminders** — configurable notifications when you've been working too long
- **Session statistics** — view your work patterns by day, week, or month
- **Session history** — browse past sessions grouped by date
- **Auto-update** — Sparkle integration for seamless updates

## Install

1. Download the latest `.zip` from [Releases](https://github.com/ta21cos/elapsed/releases)
2. Unzip and move `Elapsed.app` to `/Applications`
3. On first launch, right-click the app and select **Open** (Gatekeeper bypass, one-time only)
4. Grant **Accessibility** permission when prompted (required for activity detection)

## Requirements

- macOS 14.0 (Sonoma) or later

## Development

### Prerequisites

- Xcode 15.4+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.30+
- [fish shell](https://fishshell.com/) (for release script)
- [GitHub CLI](https://cli.github.com/) (`gh`)

### Build from source

```bash
# Generate Xcode project (required after project.yml changes)
xcodegen generate

# Debug build
xcodebuild -project Elapsed.xcodeproj -scheme Elapsed -configuration Debug build

# Release build (universal binary: arm64 + x86_64)
xcodebuild -project Elapsed.xcodeproj \
  -scheme Elapsed \
  -configuration Release \
  -derivedDataPath build \
  -arch arm64 -arch x86_64 \
  ONLY_ACTIVE_ARCH=NO \
  build
```

### XcodeGen objectVersion workaround

XcodeGen 2.44+ outputs objectVersion 77, which Xcode 15.4 cannot read. `project.yml` includes a `postGenCommand` that automatically patches it to objectVersion 56 after generation. If you upgrade to Xcode 16+, remove the `postGenCommand` line from `project.yml`.

### Project structure

```
Elapsed/
├── Models/          Session, DailySummary (SwiftData)
├── Services/        ActivityMonitor, SessionManager, BreakReminder, UpdaterController
├── Views/           SwiftUI views (Popover, Settings, Onboarding, Statistics, etc.)
├── Settings/        AppSettings
├── Utilities/       Constants, TimeFormatter, Clock
├── Resources/       Assets.xcassets (app icon)
├── ElapsedApp.swift @main entry point
└── AppCoordinator.swift  Dependency injection & coordination
```

### Data storage

SwiftData stores session data at:

```
~/Library/Application Support/default.store
```

This is a SQLite database. To inspect or clean up data:

```bash
# List tables
sqlite3 ~/Library/Application\ Support/default.store ".tables"

# Count sessions
sqlite3 ~/Library/Application\ Support/default.store "SELECT COUNT(*) FROM ZSESSION;"

# View recent sessions
sqlite3 ~/Library/Application\ Support/default.store \
  "SELECT datetime(ZSTARTTIME + 978307200, 'unixepoch', 'localtime') FROM ZSESSION ORDER BY ZSTARTTIME DESC LIMIT 10;"

# Delete sessions before a specific date (stop the app first)
sqlite3 ~/Library/Application\ Support/default.store \
  "DELETE FROM ZSESSION WHERE ZSTARTTIME < strftime('%s', '2026-03-01') - 978307200;"
sqlite3 ~/Library/Application\ Support/default.store \
  "DELETE FROM ZDAILYSUMMARY WHERE ZDATE < strftime('%s', '2026-03-01') - 978307200;"
```

## Release

### Initial setup (one-time)

1. **Download Sparkle CLI tools:**

   ```bash
   mkdir -p .sparkle-tools
   cd .sparkle-tools
   gh release download 2.9.0 -R sparkle-project/Sparkle -p 'Sparkle-2.9.0.tar.xz'
   tar xf Sparkle-2.9.0.tar.xz
   cd ..
   ```

2. **Generate EdDSA signing key:**

   ```bash
   .sparkle-tools/bin/generate_keys
   ```

   - Private key is saved to macOS Keychain automatically
   - Set the output public key in `Info.plist` → `SUPublicEDKey`
   - This only needs to be done once per machine

### Release process

Use the release script:

```fish
# Dry run (build + sign, no push/release)
./scripts/release.fish 1.2.0 --dry-run

# Full release
./scripts/release.fish 1.2.0

# Skip build (reuse existing build artifacts)
./scripts/release.fish 1.2.0 --skip-build
```

The script performs these steps:

1. Update `Info.plist` versions (`CFBundleShortVersionString` and `CFBundleVersion`)
2. Build Release (universal binary)
3. Re-sign `.app` with ad-hoc identity (required for embedded Sparkle framework)
4. Create ZIP
5. Sign ZIP with EdDSA (Sparkle update signature)
6. Generate/update `appcast.xml` (enclosure URL points at the GitHub Release asset)
7. Commit `appcast.xml` + `Info.plist`, create git tag, push
8. Create and publish the GitHub Release with the ZIP attached

### Auto-update (Sparkle)

- Feed URL: `https://raw.githubusercontent.com/ta21cos/elapsed/main/appcast.xml`
- Signing: EdDSA (private key in Keychain, public key in `Info.plist`)
- Users can check for updates manually from Settings → "アップデート" tab
- Automatic check on launch is configurable

### CI/CD

- **CI** (`ci.yml`): Runs on push to `main` and PRs. Builds Debug + runs tests.

Releases are created only by `scripts/release.fish` (run locally, because the EdDSA private key lives in the local Keychain). There is intentionally no release workflow: a CI-built ZIP would differ from the locally signed one, so its EdDSA signature in `appcast.xml` would not match and Sparkle would reject the update.

### Code signing

This app uses **ad-hoc signing** (`CODE_SIGN_IDENTITY = "-"`) without an Apple Developer Program certificate. This means:

- Users must right-click → Open on first launch to bypass Gatekeeper
- No notarization
- Embedded frameworks (Sparkle) must be re-signed with `codesign --force --deep --sign -` after build

## License

MIT
