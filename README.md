# Dumbo

A tiny energy heart for your screen time. It lives in the Dynamic Island and nudges you to breathe, sip water and rest your eyes while you scroll. Fully offline: no account, no server, nothing leaves the phone.

## How it works

- **Energy** starts at 100% when the screen turns on and drains over 25 / 45 / 60 min (Strict / Normal / Chill). A short glance away pauses it; 5+ min with the phone down starts a fresh session.
- **Nudges** every 10 min of screen-on time rotate eyes → breathe → sip, and an "out of energy" nudge at 0%. Finishing one gives +20%.
- **Dynamic Island** (Live Activity) shows the heart and session timer, and expands for nudges with one action (`+ glass`, `done`, `breathe`).
- **Summary** shows today and the last 7 days, computed on device.

## Layout

| Path | What |
| --- | --- |
| `Packages/DumboKit` | Shared logic and views: energy/session engine, prompt scheduler, line deck, summaries, JSON store in the App Group, island views, Live Activity controller. Unit tested. |
| `Dumbo` | iPhone app (SwiftUI): onboarding, home, summary, settings, exercises, demo mode. |
| `DumboWidgets` | Live Activity / Dynamic Island and the Today widget. |
| `DumboMonitor` | Screen Time (DeviceActivity) monitor extension that turns usage thresholds into session check-ins. |
| `Shared` | App Intents used by island buttons (compiled into the app and the widget extension). |

## Build

```sh
brew install xcodegen
xcodegen generate          # regenerates Dumbo.xcodeproj from project.yml
open Dumbo.xcodeproj
```

Run the `Dumbo` scheme on an iOS 17+ simulator. Without Screen Time, use **Try the demo** in onboarding (or Settings → Demo mode): every second counts as one minute of screen use, so nudges show up quickly.

Tests: `cd Packages/DumboKit && swift test`

### On a real iPhone

Screen Time needs a paid Apple Developer account and the Family Controls capability. Set your team in Xcode for all three targets, and keep the App Group `group.com.sarthib7.dumbo` (or change it in `project.yml` and `DumboStore.appGroup`).

### Screenshot flags

`-seed YES` loads a sample week. `-screen today|week|settings|gallery|breathe|sip|eyes|nudge-<breathe|sip|eyes|empty>` opens a screen. `-freeze <seconds>` pins exercise animations.

## TestFlight

```sh
APPLE_TEAM_ID=… ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_KEY_P8="$(cat AuthKey_XXXX.p8)" scripts/testflight.sh
```

Signs manually with the team's Apple Distribution certificate (must be in the keychain) and App Store profiles that `scripts/asc_profiles.py` creates through the App Store Connect API, then uploads with `altool`. Xcode's automatic signing can't be used with an API key here because Apple doesn't expose App Groups to API keys.

- Default: signed without Family Controls, because TestFlight needs Apple's Family Controls distribution approval. Once that is granted, run with `SCREEN_TIME=1`.
- `APP_GROUP=0`: also signed without the App Group, for when `group.com.sarthib7.dumbo` isn't linked to the three bundle IDs in the developer portal yet. The app and island work; widgets show no data.
