# Tink-on for iOS

Current update: **1.1.1 (14)**. See [the release package](AppStoreRelease/1.1.1-build13/README.md) for the signed archive and App Store Connect status.

A native SwiftUI instrument with UIKit drawing and AVAudioEngine playback. No third-party packages or web view. Requires Xcode 26+; runs on iOS/iPadOS 17+.

## Run

Open `TinkOn.xcodeproj`, select the **TinkOn** scheme and an iPhone or iPad simulator, and press Run. On iPhone the instrument supports both landscape directions. iPad also supports portrait and resizable windows.

Build 10 selects AI + SYNTH for a new kit, with a one-time permission prompt before any AI request. Use Offline Synth chooses local generation and persists that choice. Disabling AI clears the saved permission. Existing sound-source preferences are preserved. AI + SYNTH in Settings sends a derived description and duration through Tink-on's HTTPS endpoint to ElevenLabs, with local synthesis on network, quota or audio failure. No provider key is bundled in the app. A build 7 kit without the AI preference loads with AI disabled.

The current kit saves in the app's Application Support directory: sketch, pads, pitches, 16-step beat, tempo and source preference. iPhone exposes eight pads in a 4×2 grid; iPad exposes twelve in a 4×3 grid. Existing eight-pad kits expand without losing sounds or recorded steps. AI audio is decoded, trimmed to the sketch's duration and stored as PCM CAF. Saved audio remains playable offline. Share a selected pad through the iOS share sheet as a pitched WAV file. There is no microphone recording or background playback; calls, headphone removal and backgrounding stop the transport.

## Signing

`Config.xcconfig` contains the approved bundle ID `com.tinkon.app` and Zui Chen developer team `9PFHA8HVMX`. Confirm registration and provisioning in Xcode's Signing & Capabilities tab before distribution. Apple does not allow changing an uploaded app's bundle ID.

## Verify

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project ios/TinkOn.xcodeproj -scheme TinkOn \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath ios/build -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO test
```

Run from the repository root. Unit tests cover sketch mapping, all four synth voices, pitch, pixel previews, kit persistence and audio encoding/decoding. UI tests exercise drawing → generation → pad playback → live recording → cold relaunch → WAV sharing. See `../docs/IOS-RELEASE.md` for physical-device and distribution checks.

## Files

- `TinkOn/Models.swift`: normalized sketches, feature analysis, kit format and persistence.
- `TinkOn/AudioEngine.swift`: PCM synthesis, decoding, pitch, player pool and host-clock sequencer.
- `TinkOn/SketchView.swift`: UIKit drawing with coalesced touches and independent touch-down pads.
- `TinkOn/Instrument.swift`: generation, transport, persistence, interruption handling and sharing.
- `TinkOn/InstrumentView.swift`: instrument layout, pad artwork, settings and share sheet.
- `TinkOn/SoundService.swift`: bounded AI requests, response validation, audio decoding and local storage.
- `TinkOn/PrivacyInfo.xcprivacy`: unlinked AI-derived user content for app functionality and other purposes, plus linked request diagnostics for app functionality; no tracking.

Settings links the app-specific [support page](https://tinkon.zui.ooo/support.html) and [privacy policy](https://tinkon.zui.ooo/privacy.html). `AppStoreRelease/README.md` tracks the current release package and remaining submission work. The screenshot presentation kit is local simulator data and is not bundled with the app.

The manifest includes the required system-clock reason `35F9.1` for the audio sequencer's host-time calculations. Host clock values stay on the device.

`scripts/generate_project.py` regenerates the committed project without extra tooling; it replaces project and scheme settings, so preserve manual Xcode changes before running it. `scripts/create_icon.swift` creates the four-ink sketch app icon as an opaque 1024×1024 PNG. The 1.1.1 update contains this icon.
