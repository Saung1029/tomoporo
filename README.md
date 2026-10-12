# 🍅 Tomoporo

A tiny native macOS **menu bar Pomodoro timer** written in a single Swift file. No dependencies, no Electron, no Xcode project — just `swiftc` and you're done.

## Features

- 🍅 Lives in your **menu bar** with a live countdown (`🍅 24:59` work / `☕ 04:12` rest)
- ⏱ Adjustable work & rest lengths (presets 15/25/50 and 5/10/15, or any custom minutes) — defaults to the classic 25/5
- 🎆 **Fireworks celebration** across your screen + congratulation notification when a focus session completes (can be toggled off)
- ☕ When the break ends, it notifies you and **waits** — you decide when the next pomodoro starts
- 📝 Automatic log: every completed pomodoro earns a **random emoji trophy** (🚀🍩⭐🦄…), recorded per day with total focus time
- ▶️ Pause / resume, skip phase, stop & reset

## The log

Two files are written to `~/Library/Application Support/Tomoporo/`:

- `tomoporo-log.md` — human-readable, e.g.

  ```
  ## 2026-10-06
  🚀🍩⭐🦄 — 4 pomodoros, 1h 40m focus
  ```

- `tomoporo-log.json` — the raw data

Open it anytime from the menu: **Open Log**.

## Build & run

Requires macOS with the Xcode Command Line Tools (`xcode-select --install`).

```bash
./build.sh            # builds Tomoporo.app in this folder
./build.sh --install  # builds and installs to /Applications (Spotlight: search "Tomoporo")
```

Then launch it via Spotlight (`Cmd+Space`, type `Tomoporo`) or `open Tomoporo.app`. Look for the 🍅 in your menu bar.

## Start at login (optional)

Create `~/Library/LaunchAgents/com.kkbest.tomoporo.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.kkbest.tomoporo</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/Tomoporo.app/Contents/MacOS/tomoporo</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
```

Then:

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.kkbest.tomoporo.plist
```

To remove it later:

```bash
launchctl bootout gui/$(id -u)/com.kkbest.tomoporo
rm ~/Library/LaunchAgents/com.kkbest.tomoporo.plist
```

## License

MIT
