# Cards Reader (iOS)

A native SwiftUI reader for a scanned greeting-card archive published as a static
site to a self-hosted
pages server.

The app downloads the site's generated `index.html`, reads the embedded
`const CARDS = [...]` data and the section headers, and renders everything natively.
Rebuilding and redeploying the site updates the app on the next refresh. Nothing on
the server needs to change.

## Features

- **Cards:** collection filter chips, full-text search over names, messages and
  publishers, and a grid of covers that uses the cover page the site picks for each card.
- **Card detail:** swipe between cards. Each card shows every scanned page and the full
  transcript, with a share button for the transcript. Tap a page to open it full screen
  with pinch and double-tap zoom.
- **Years:** every card on one timeline, newest first.
- **Collages:** the live site in a web view, since collages are laid out in the browser
  and saved back to the server.
- Works offline from the last downloaded copy, and caches scans on disk (up to 2 GB).
- Light and dark mode in the site's paper-and-ink palette.

## Build

Requires Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
cp Config.example.xcconfig Config.xcconfig   # set server URL, team ID, bundle ID
xcodegen generate
open Cards.xcodeproj
```

`Config.xcconfig` is gitignored. It holds the archive server URL (`CARDS_SERVER_URL`),
which the app reads from its Info.plist at launch, plus your signing team and bundle ID.
